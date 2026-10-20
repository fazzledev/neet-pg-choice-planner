require "open3"

module MccResults
  class LayoutCheck
    NUMBERED_ROW = /\A {0,5}(\d+)\s+(\d+)(?=\s|\z)/
    NUMBERED_FRAGMENT = /\A {0,5}(\d+)(?:\s+(\d+))?(?=\s|\z)/
    RANKED_ROW = /\A {0,4}(\d+)(?=\s)/
    RANK_FRAGMENT_END = 12
    FRAGMENT_DRIFT = 2

    Result = Data.define(:pages_checked, :mismatched_pages, :serials_consecutive)

    def initialize(pdf)
      @pdf = pdf
    end

    def run
      texts = layout_pages
      checked = @pdf.pages.select(&:table?)
      serials = []
      mismatched = checked.filter_map do |page|
        expected = layout_rows(texts.fetch(page.number - 1, ""))
        serials.concat(expected.map(&:first))
        actual = page.rows.map(&:rank)
        [page.number, actual, expected.map(&:last)] unless actual == expected.map(&:last)
      end
      consecutive = serials.compact.then { |numbers| numbers.empty? || numbers == (1..numbers.size).to_a } if @pdf.numbered?
      Result.new(pages_checked: checked.size, mismatched_pages: mismatched, serials_consecutive: consecutive)
    end

    private

    def layout_pages
      output, status = Open3.capture2("pdftotext", "-layout", @pdf.path, "-")
      raise "pdftotext failed on #{@pdf.path}" unless status.success?

      output.split("\f")
    end

    def layout_rows(text)
      return text.lines.filter_map { _1[RANKED_ROW, 1]&.then { |rank| [nil, rank.to_i] } } unless @pdf.numbered?

      lines_since_start = nil
      text.lines.each_with_object([]) do |line, rows|
        fragment = line.match(NUMBERED_FRAGMENT)
        if fragment && lines_since_start && lines_since_start <= FRAGMENT_DRIFT && rows.last.first + 1 != fragment[1].to_i
          rank = fragment[2] && fragment.end(2) <= RANK_FRAGMENT_END ? fragment[2] : ""
          rows[-1] = ["#{rows.last.first}#{fragment[1]}".to_i, "#{rows.last.last}#{rank}".to_i]
          lines_since_start = nil
        elsif (start = line.match(NUMBERED_ROW))
          rows << [start[1].to_i, start[2].to_i]
          lines_since_start = 0
        else
          lines_since_start &&= lines_since_start + 1
        end
      end
    end
  end
end
