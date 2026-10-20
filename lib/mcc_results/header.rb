module MccResults
  class Header
    class LayoutError < StandardError; end

    SINGLE_ROUND = %i[quota institute course allotted_category candidate_category remarks].freeze
    MULTI_ROUND = %i[quota institute course allotted_category candidate_category option remarks].freeze
    PREVIOUS_ROUND_WIDTH = 4
    LABEL_GAP = 4.5
    LINE = 10

    attr_reader :columns, :fields, :rank_column, :bottom

    def self.find(words)
      label = words.select { _1.text == "Rank" }.min_by(&:y0)
      return unless label && words.any? { |w| w.text == "Remarks" && (w.y0 - label.y0).abs < LINE }

      first = words.select { |w| w.number? && w.y0 > label.y1 && w.center.between?(label.x0 - 5, label.x1 + 5) }.min_by(&:y0)
      raise LayoutError, "header without ranks" unless first

      new(label, words.select { |w| w.y0 >= label.y0 - 4 && w.y0 < first.y0 - 2 }, bottom: first.y0 - 2)
    end

    def initialize(label, words, bottom:)
      @bottom = bottom
      @columns = label_columns(words)
      @rank_column = @columns.index { |x0, x1| label.center.between?(x0, x1) }
      multi_round = words.any? { _1.text == "option" }
      layout = multi_round ? MULTI_ROUND : SINGLE_ROUND
      previous = @columns.size - @rank_column - 1 - layout.size
      unless previous >= 0 && previous % PREVIOUS_ROUND_WIDTH == 0 && multi_round == previous.positive?
        raise LayoutError, "#{@columns.size} header columns with rank at #{@rank_column}"
      end

      @fields = Array.new(@columns.size - layout.size) + layout
    end

    private

    def label_columns(words)
      words.sort_by(&:x0).each_with_object([]) do |word, columns|
        if columns.any? && word.x0 <= columns.last.last + LABEL_GAP
          columns.last[1] = [columns.last.last, word.x1].max
        else
          columns << [word.x0, word.x1]
        end
      end
    end
  end
end
