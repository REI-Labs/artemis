#!/usr/bin/env python3
"""Validate the raw, application-owned values interface before Helm merges it."""

import argparse
import json
import re
import sys
from pathlib import Path

import yaml


class UniqueLoader(yaml.SafeLoader):
    pass


def construct_mapping(loader, node):
    result = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node)
        if not isinstance(key, str) or key in result:
            raise ValueError(f"duplicate or non-string YAML key: {key!r}")
        result[key] = loader.construct_object(value_node)
    return result


UniqueLoader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, construct_mapping)


def validate_shape(value, schema, chart, path):
    if value is None:
        raise ValueError(f"{path}: null cannot remove a platform or Profile value")
    if "$ref" in schema:
        ref = schema["$ref"]
        if not ref.startswith("#/$defs/"):
            raise ValueError(f"{path}: unsupported chart schema reference {ref}")
        schema = chart["$defs"][ref.removeprefix("#/$defs/")]
    expected = schema.get("type")
    types = {
        "object": lambda v: isinstance(v, dict),
        "array": lambda v: isinstance(v, list),
        "string": lambda v: isinstance(v, str),
        "integer": lambda v: type(v) is int,
        "number": lambda v: type(v) in (int, float),
        "boolean": lambda v: type(v) is bool,
    }
    if expected and not types[expected](value):
        raise ValueError(f"{path}: expected {expected}, got {type(value).__name__}")
    if isinstance(value, (dict, list)) and not value and not (
        isinstance(value, list) and path.endswith(".queues")
    ):
        raise ValueError(f"{path}: empty container can erase inherited settings")
    if isinstance(value, dict):
        properties = schema.get("properties", {})
        additional = schema.get("additionalProperties", True)
        names = schema.get("propertyNames", {})
        for key, child in value.items():
            if not isinstance(key, str):
                raise ValueError(f"{path}: mapping keys must be strings")
            if names.get("pattern") and not re.fullmatch(names["pattern"], key):
                raise ValueError(f"{path}.{key}: invalid field name")
            rule = properties.get(key, additional)
            if rule is False:
                raise ValueError(f"{path}.{key}: field is not allowed")
            validate_shape(child, rule if isinstance(rule, dict) else {}, chart, f"{path}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            validate_shape(child, schema.get("items", {}), chart, f"{path}[{index}]")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("values", type=Path)
    parser.add_argument("--chart-schema", type=Path, required=True)
    args = parser.parse_args()
    chart = json.loads(args.chart_schema.read_text())
    try:
        documents = list(yaml.load_all(args.values.read_text(), Loader=UniqueLoader))
        if len(documents) != 1 or not isinstance(documents[0], dict):
            raise ValueError("values must contain exactly one YAML mapping")
        values = documents[0]
        allowed = {
            "services": {"brokerAlias"},
            "acceptors": None,
            "authentication": {"jaasSecretName"},
            "destinations": None,
            "authorization": {"rules"},
            "networkPolicy": {"clientSources", "clientCidrs"},
        }
        for key, value in values.items():
            path = f"workloadValues.{key}"
            if key not in allowed:
                raise ValueError(f"{path}: protected or unknown field")
            if allowed[key] is not None:
                if not isinstance(value, dict):
                    raise ValueError(f"{path}: expected object")
                for child in value:
                    if child not in allowed[key]:
                        raise ValueError(f"{path}.{child}: protected or unknown field")
            validate_shape(value, chart["properties"][key], chart, path)
    except (ValueError, yaml.YAMLError) as error:
        print(f"raw workload override rejected: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
