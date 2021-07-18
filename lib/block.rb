# frozen_string_literal: true

# Provides an abstraction for performing boolean operations on a numerical range.
# Used for calculating the interaction of free and busy time periods on a schedule.
#
# A Block is a VALUE OBJECT which has a starting value (called `top` or `start`)
# and an ending value (called `bottom` or `end`). These properties are numeric
# values which could represent points in time, or an arbitrary numeric scale.
#
# Blocks can be combined and subtracted from one another to yield other blocks
# or arrays of blocks depending on whether the original blocks are contiguous or not.
#
# For example:
#   Addition of overlapping ranges:
#   Block.new(3, 8) + Block.new(5, 12) == Block.new(3, 12)
#
#   Subtraction of one block from the middle of another:
#   Block.new(5, 25) - Block.new(10, 20) == [Block.new(5, 10), Block.new(20, 25)]
#
class Block
  def initialize(from, to)
    if to < from
      @start = to
      @end = from
    else
      @start = from
      @end = to
    end
  end

  def self.init_from_block(other)
    Block.new(other.start, other.end)
  end

  def inspect
    { start: start, end: self.end }.inspect
  end

  attr_reader :start, :end

  alias top start

  alias bottom end

  # ==========
  # = Length =
  # ==========

  def length
    bottom - top
  end

  # ==============
  # = Comparison =
  # ==============

  def ==(other)
    top == other.top && bottom == other.bottom
  end

  def <=>(other)
    [top, bottom] <=> [other.top, other.bottom]
  end

  def include?(n)
    top <= n && bottom >= n
  end

  # ============
  # = Position =
  # ============

  # This block entirely surrounds the other block.

  def surrounds?(other)
    other.top > top && other.bottom < bottom
  end

  def covers?(other)
    other.top >= top && other.bottom <= bottom
  end

  # This block intersects with the top of the other block.

  def intersects_top?(other)
    top <= other.top && other.include?(bottom)
  end

  # This block intersects with the bottom of the other block.

  def intersects_bottom?(other)
    bottom >= other.bottom && other.include?(top)
  end

  # This block overlaps with any part of the other block.

  def overlaps?(other)
    include?(other.top) || other.include?(top)
  end

  # ==============
  # = Operations =
  # ==============

  # A block encompassing both this block and the other.

  def union(other)
    Block.new([top, other.top].min, [bottom, other.bottom].max)
  end

  # A two element array of blocks created by cutting the other block out of this one.

  def split(other)
    [Block.new(top, other.top), Block.new(other.bottom, bottom)]
  end

  # A block created by cutting the top off this block.

  def trim_from(new_top)
    Block.new(new_top, bottom)
  end

  # A block created by cutting the bottom off this block.

  def trim_to(new_bottom)
    Block.new(top, new_bottom)
  end

  def limited(limiter)
    Block.new([top, limiter.top].max, [bottom, limiter.bottom].min)
  end

  def padded(top_padding, bottom_padding)
    Block.new(top - [top_padding, 0].max, bottom + [bottom_padding, 0].max)
  end

  # =============
  # = Operators =
  # =============

  # Return the result of adding the other Block (or Blocks) to self.

  def add(other)
    return [Block.new(top, bottom)] if surrounds?(other)
    return [Block.init_from_block(other)] if other.surrounds?(self)
    return [Block.new(top, other.bottom)] if intersects_top?(other)
    return [Block.new(other.top, bottom)] if other.intersects_top?(self)

    [Block.init_from_block(other), Block.init_from_block(self)]
  end

  # Return the result of subtracting the other Block (or Blocks) from self.

  def subtract(other)
    if other.is_a?(Block)
      return [Block.new(top, other.top), Block.new(bottom, other.bottom)] if surrounds?(other)
      return [] if other.covers?(self)
      return [Block.new(other.bottom, bottom)] if other.intersects_top?(self)

      [Block.new(start, other.start)]
    else
      result = [self]
      other.each do |s|
        result[-1] = result[-1] - s
        result.flatten!
      end
      result
    end
  end

  alias - subtract

  alias + add

  # An array of blocks created by adding each block to the others.

  def self.merge(blocks_array)
    blocks_array.sort_by(&:top).inject([]) do |blocks, b|
      if !blocks.empty? && blocks.last.overlaps?(b)
        blocks[0...-1] + (blocks.last + b)
      else
        blocks + [b]
      end
    end
  end

  def merge(others)
    Block.merge([self, others].flatten)
  end
end
