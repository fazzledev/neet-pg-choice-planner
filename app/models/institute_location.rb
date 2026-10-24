module InstituteLocation
  PATH = Rails.root.join("data/institute_locations.json")

  def self.all
    @all ||= PATH.exist? ? JSON.parse(PATH.read).compact : {}
  end

  def self.dump(found)
    rows = found.sort.map { |code, place| "  #{code.to_json}: #{place.to_json}" }
    "{\n#{rows.join(",\n")}\n}\n"
  end
end
