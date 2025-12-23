#!/usr/bin/env python3
import csv
import xml.etree.ElementTree
from pathlib import Path
import pytest

@pytest.fixture
def project_root():
    return Path(__file__).parent.parent

@pytest.fixture
def tiles(project_root):
    tiles_filename = project_root / "tiles.csv"
    return read_tiles(tiles_filename)

@pytest.fixture
def id_to_tile(tiles):
    return get_id_to_tile(tiles)

@pytest.fixture
def csv_map(project_root):
    map_filename = project_root / "map.csv"
    return read_csv_map(map_filename)

@pytest.fixture
def tmx_map(project_root):
    tmx_filename = project_root / "train-conductor-world.tmx"
    return read_map_from_tmx(tmx_filename)

def test_map_tile_ids_in_csv(csv_map, id_to_tile):
    tile_ids = set()
    for row in csv_map:
        for tile_id in row:
            tile_ids.add(tile_id)

    assert tile_ids.issubset(set(id_to_tile))

def test_map_tile_id_maps_to_group(csv_map, id_to_tile):
    for row in csv_map:
        for tile_id in row:
            if 0 <= tile_id <= 10:
                assert id_to_tile[tile_id]["Group"] == "Environment"
            if 11 <= tile_id <= 39:
                assert id_to_tile[tile_id]["Group"] == "Location"
            if 40 <= tile_id <= 103:
                assert id_to_tile[tile_id]["Group"] == "Track"
            assert not tile_id > 103

def test_map_tile_id_tmx_id(csv_map, id_to_tile):
    for row in csv_map:
        for tile_id in row:
            assert int(id_to_tile[tile_id]["Tmx Id"]) == tile_id + 1

def test_tmx_csv_same_size_as_map_csv(csv_map, tmx_map):
    assert len(csv_map) == len(tmx_map)
    for csv_row, tmx_row in zip(csv_map, tmx_map):
        assert len(csv_row) == len(tmx_row)

def test_tmx_csv_equivalent_to_map_csv(csv_map, tmx_map):
    for y, (csv_row, tmx_row) in enumerate(zip(csv_map, tmx_map)):
        for x, (csv_tile_id, tmx_tile_id) in enumerate(zip(csv_row, tmx_row)):
            assert csv_tile_id + 1 == tmx_tile_id

def test_location_positions(csv_map, id_to_tile):
    positions = []
    for y, row in enumerate(csv_map):
        for x, tile_id in enumerate(row):
            tile = id_to_tile[tile_id]
            if tile["Group"] == "Location":
                assert int(tile["X"]) == x
                assert int(tile["Y"]) == y

def get_id_to_tile(tiles):
    return {
        int(row["Id"]): row
        for row in tiles
    }

def read_map_from_tmx(tmx_filename):
    tree = xml.etree.ElementTree.parse(tmx_filename)
    root = tree.getroot()
    layers = root.findall("layer")
    map_data = layers[0].find("data").text.strip().splitlines()
    csv_map_data = [
        line.rstrip(",")
        for line in map_data
    ]
    tmx_csv_map = []
    for row in csv.reader(csv_map_data):
        tmx_csv_map.append(list(map(int, row)))
    return tmx_csv_map

def read_csv_map(map_filename):
    csv_map = []
    with open(map_filename, newline="") as f:
        for row in csv.reader(f):
            csv_map.append(list(map(int, row)))
    return csv_map


def read_tiles(tiles_filename):
    tiles = []
    with open(tiles_filename, newline="") as f:
        reader = csv.DictReader(f)
        data_types = next(reader)
        for row in reader:
            tiles.append(row)
    return tiles
