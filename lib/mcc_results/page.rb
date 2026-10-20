module MccResults
  class Page
    Row = Data.define(:rank, :cells)

    LINE_TOLERANCE = 4
    ROW_TOLERANCE = 2
    WRAPPED_LINE = 1.25
    WRAPPING_DIGITS = 5

    attr_reader :number, :header, :lead, :rows, :forced_splits

    def initialize(words, number:, header: nil)
      @words = words
      @number = number
      @own_header = Header.find(words)
      @header = @own_header || header
      @lead = {}
      @rows = []
      @forced_splits = 0
      parse if @header
    rescue Header::LayoutError => error
      raise Header::LayoutError, "page #{number}: #{error.message}"
    end

    def table? = !@header.nil?

    private

    def parse
      top = @own_header ? @own_header.bottom : -Float::INFINITY
      floor = bottom
      table = @words.select { |w| w.y0 >= top && w.y0 < floor }
      edges = header.columns.each_cons(2).map { |left, right| split(left.last, right.first, table) }

      cells = Hash.new { |hash, key| hash[key] = Hash.new { |inner, field| inner[field] = [] } }
      ranks = table.select { |w| w.number? && column_of(w, edges) == header.rank_column }.sort_by(&:y0).chunk_while { |a, b| wrapped?(a, b) }
      anchors = ranks.map(&:first)
      table.each do |word|
        column = column_of(word, edges)
        next if column == header.rank_column

        field = header.fields[column] or next
        anchor = anchors.reverse_each.find { _1.y0 - ROW_TOLERANCE <= word.y0 }
        cells[anchor][field] << word
      end

      @lead = joined(cells[nil])
      @rows = ranks.map { Row.new(rank: _1.map(&:text).join.to_i, cells: joined(cells[_1.first])) }
    end

    def wrapped?(fragment, following)
      fragment.text.size >= WRAPPING_DIGITS && following.y0 - fragment.y0 < (fragment.y1 - fragment.y0) * WRAPPED_LINE
    end

    def bottom
      footer = @words.find { |w| w.text == "Page" && @words.any? { |n| n.text == "No." && (n.y0 - w.y0).abs < ROW_TOLERANCE && n.x0 > w.x1 } }
      footer ? footer.y0 - 1 : Float::INFINITY
    end

    def split(left, right, words)
      return (left + right) / 2 if right <= left

      spans = words.filter_map { |w| [[w.x0, left].max, [w.x1, right].min] if w.x1 > left && w.x0 < right }.sort
      cursor = left
      gaps = []
      spans.each do |x0, x1|
        gaps << [cursor, x0] if x0 > cursor
        cursor = [cursor, x1].max
      end
      gaps << [cursor, right] if right > cursor
      widest = gaps.max_by { _2 - _1 }
      return widest.sum / 2 if widest

      @forced_splits += 1
      (left + right) / 2
    end

    def column_of(word, edges)
      edges.count { _1 <= word.center }
    end

    def joined(fields)
      fields.transform_values do |words|
        lines = words.sort_by(&:y0).chunk_while { |a, b| (b.y0 - a.y0).abs < LINE_TOLERANCE }
        lines.map { |line| line.sort_by(&:x0).map(&:text).join(" ") }.join(" ")
      end
    end
  end
end
