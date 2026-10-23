extends Node


# Cell IDs
const EMPTY = Vector2i(-1, -1)
const ARROW = Vector2i(0, 0)
const OBSTACLE = Vector2i(1, 0)
const WALL = Vector2i(2, 0)
const TELEPORTER = Vector2i(0, 1)
const SPLITTER = Vector2i(1, 1)
const BUTTON = Vector2i(2, 1)
const REWIND = Vector2i(0, 2)
const START = Vector2i(2, 2)
const GOAL = Vector2i(1, 2)
const USER_WALL = Vector2i(0, 3)
const DEATH = Vector2i(1, 3)
const BUILD_AREA = Vector2i(4, 0)
const DESTROYER = Vector2i(0, 4)


# Cardinal directions
const NORTH = 0
const EAST = 1
const SOUTH = 2
const WEST = 3


# Relative directions
const FORWARD = 0
const RIGHT = 1
const BACK = 2
const LEFT = 3
