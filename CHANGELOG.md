# Changelog

All notable changes to this project will be documented in this file.

## [1.2.10] - 2026-07-28

### Fixed
- Arrows could only extend right, down, or diagonally-down, so a corner
  cell could never host part of an arrow — arrows clustered heavily
  toward the grid's center (the center 3×3 box was touched roughly 1.8×
  more often than a corner box). Arrows now use all 8 directions and are
  each assigned to a different one of the grid's 9 boxes, spreading them
  across the whole grid.
