require "open3"

module MccResults
  class ResultPdf
    Allotment = Data.define(:year, :round, :rank, :quota, :institute, :course, :allotted_category, :candidate_category, :remarks)

    FIELDS = Allotment.members
    REQUIRED = %i[quota institute course allotted_category candidate_category].freeze
    NOT_ALLOTTED = ["", "-"].freeze
    CHUNK = 100
    HEADER_SEARCH = 10

    attr_reader :path, :year, :round

    def self.all(root, year: nil, round: nil)
      Dir[File.join(root, "*", "*.pdf")].sort.filter_map do |path|
        file_year = File.basename(File.dirname(path))
        file_round = File.basename(path, ".pdf")
        new(path, year: file_year.to_i, round: file_round) if [nil, file_year].include?(year&.to_s) && [nil, file_round].include?(round)
      end
    end

    def initialize(path, year:, round:, workers: Etc.nprocessors)
      @path = path.to_s
      @year = year
      @round = round
      @workers = workers
    end

    def page_count
      @page_count ||= Integer(pdftool("pdfinfo", @path)[/^Pages:\s+(\d+)/, 1])
    end

    def allotments
      @allotments ||= rows.filter_map do |row|
        cells = row.cells
        next if NOT_ALLOTTED.include?(cells[:quota].to_s) && NOT_ALLOTTED.include?(cells[:institute].to_s)

        Allotment.new(year: year, round: round, rank: row.rank, **(FIELDS - %i[year round rank]).to_h { [_1, cells[_1].to_s] })
      end
    end

    def rows
      @rows ||= pages.each_with_object([]) do |page, rows|
        if page.lead.any? && rows.any?
          rows[-1] = rows[-1].with(cells: rows[-1].cells.merge(page.lead) { |_, before, after| "#{before} #{after}" })
        end
        rows.concat(page.rows)
      end
    end

    def pages
      @pages ||= read_all_pages
    end

    def orphan_leads
      pages.take_while { _1.rows.empty? }.count { _1.lead.any? }
    end

    def forced_splits
      pages.sum(&:forced_splits)
    end

    def numbered?
      header.rank_column.positive?
    end

    private

    def read_all_pages
      header
      chunks = (1..page_count).each_slice(CHUNK).map { [_1.first, _1.last] }
      return chunks.flat_map { read_pages(*_1) } if @workers < 2 || chunks.size < 2

      chunks.each_with_index.group_by { |_, index| index % @workers }.values.map do |jobs|
        reader, writer = IO.pipe
        pid = fork do
          reader.close
          results = begin
            jobs.map { |chunk, index| [index, read_pages(*chunk)] }
          rescue => error
            error
          end
          Marshal.dump(results, writer)
          writer.close
          exit!(0)
        end
        writer.close
        Thread.new { Marshal.load(reader).tap { Process.wait(pid) } }
      end.flat_map do |thread|
        thread.value.tap { raise _1 if _1.is_a?(Exception) }
      end.sort_by(&:first).flat_map(&:last)
    end

    def read_pages(first, last)
      page_words(first, last).each_with_index.map do |words, offset|
        number = first + offset
        Page.new(words, number: number, header: (header if number >= header_page))
      end
    end

    def header = located.first

    def header_page = located.last

    def located
      @located ||= page_words(1, [HEADER_SEARCH, page_count].min).each.with_index(1).lazy.filter_map { |words, number| (found = Header.find(words)) && [found, number] }.first or
        raise Header::LayoutError, "no header in #{@path}"
    end

    def page_words(first, last)
      doc = Nokogiri::XML(pdftool("pdftotext", "-bbox-layout", "-f", first.to_s, "-l", last.to_s, @path, "-"))
      doc.remove_namespaces!
      doc.xpath("//page").map do |page|
        page.xpath(".//word").map { |w| Word.new(x0: w["xMin"].to_f, y0: w["yMin"].to_f, x1: w["xMax"].to_f, y1: w["yMax"].to_f, text: w.text) }
      end
    end

    def pdftool(*command)
      output, status = Open3.capture2(*command)
      raise "#{command.first} failed on #{@path}" unless status.success?

      output
    end
  end
end
