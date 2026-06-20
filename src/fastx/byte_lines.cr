module Fastx
  # Buffered line scanner that yields slices into a reusable internal buffer.
  # Returned slices are valid only until the next call to `next_line`.
  private class ByteLines
    def initialize(@io : IO, capacity : Int32 = 64 * 1024)
      @buffer = Bytes.new(capacity)
      @start = 0
      @size = 0
      @eof = false
    end

    def next_line : Bytes?
      loop do
        if newline = find_newline
          line = @buffer[@start, newline - @start]
          @start = newline + 1
          return chomp_cr(line)
        end

        return final_line if @eof

        refill
      end
    end

    private def find_newline : Int32?
      count = @size - @start
      return if count <= 0

      relative = @buffer[@start, count].index(0x0Au8)
      relative ? @start + relative : nil
    end

    private def final_line : Bytes?
      return if @start >= @size

      line = @buffer[@start, @size - @start]
      @start = @size
      chomp_cr(line)
    end

    private def chomp_cr(line : Bytes) : Bytes
      return line unless line.size > 0 && line[line.size - 1] == 0x0Du8

      line[0, line.size - 1]
    end

    private def refill
      remaining = @size - @start
      if @start > 0
        @buffer[@start, remaining].move_to(@buffer) if remaining > 0
        @start = 0
        @size = remaining
      end

      if @size == @buffer.size
        new_buffer = Bytes.new(@buffer.size * 2)
        @buffer.copy_to(new_buffer)
        @buffer = new_buffer
      end

      read = @io.read(@buffer[@size, @buffer.size - @size])
      if read == 0
        @eof = true
      else
        @size += read
      end
    end
  end
end
