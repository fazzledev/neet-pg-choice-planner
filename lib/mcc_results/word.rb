module MccResults
  Word = Data.define(:x0, :y0, :x1, :y1, :text) do
    def center = (x0 + x1) / 2

    def number? = text.match?(/\A\d+\z/)
  end
end
