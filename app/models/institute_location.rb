module InstituteLocation
  PATH = Rails.root.join("data/institute_locations.json")

  def self.all
    @all ||= PATH.exist? ? JSON.parse(PATH.read).compact : {}
  end
end
