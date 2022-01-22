#!/usr/bin/env python3

import csv
import sys
import json

def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <tiles.csv>")
        raise SystemExit

    tiles_filename = sys.argv[1]
    to_json(tiles_filename)

def to_json(tiles_filename):
    tiles = read_cleaned_tiles(tiles_filename)
    with open(tiles_filename.replace(".csv", ".json"), "w") as f:
        json.dump(tiles, f, indent=2, ensure_ascii=False)

def read_cleaned_tiles(tiles_filename):
    tiles = []
    with open(tiles_filename, newline="") as f:
        reader = csv.DictReader(f)
        data_types = next(reader)
        for row in reader:
            tiles.append(clean_row(row, data_types))
    return tiles

def clean_row(row, data_types):
    return {
        key.lower().replace(" ", "_"): cast_item(key, value, data_types)
        for key, value in row.items()
        if value
    }

def cast_item(key, value, data_types):
    if data_types[key] == "String":
        return value        
    if data_types[key] == "Integer":
        return int(value)
    if data_types[key] == "Float":
        return float(value)
    if data_types[key] == "Boolean":
        return value == "TRUE"
    if data_types[key] == "List":
        return value.split(", ")

    raise ValueError(f"Unxpected type '{data_type}' found")

if __name__ == "__main__":
    main()
