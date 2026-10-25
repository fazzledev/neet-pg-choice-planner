module InstituteTitle
  PATH = Rails.root.join("data/institute_titles.json")

  def self.all
    @all ||= PATH.exist? ? JSON.parse(PATH.read) : {}
  end

  def self.for(code, name)
    all[code] || InstituteName.shorten(name)
  end
end
