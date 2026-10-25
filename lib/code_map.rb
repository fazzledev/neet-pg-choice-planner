module CodeMap
  def self.dump(by_code)
    rows = by_code.sort.map { |code, value| "  #{code.to_json}: #{value.to_json}" }
    "{\n#{rows.join(",\n")}\n}\n"
  end
end
