class CatalogImport
  def initialize(path, name:, slug:, activate: true)
    @data = JSON.parse(File.read(path))
    @name = name
    @slug = slug
    @activate = activate
  end

  def run
    Counselling.transaction do
      counselling = Counselling.find_or_initialize_by(slug: @slug)
      counselling.update!(name: @name)
      Counselling.where.not(id: counselling.id).update_all(active: false) if @activate
      counselling.update!(active: true) if @activate

      institutes = @data["institutes"].to_h do |row|
        institute = counselling.institutes.find_or_initialize_by(code: row["code"])
        institute.update!(name: row["name"], address: row["address"], type_code: row["type_code"], type_name: row["type_name"])
        [row["code"], institute]
      end

      names = @data["programs"].merge(@data["choices"].to_h { [_1["brcd"], _1["program"]] }) { |_, listed, _| listed }
      programs = names.to_h do |code, name|
        program = counselling.programs.find_or_initialize_by(code: code)
        program.update!(name: name)
        [code, program]
      end

      @data["choices"].each do |row|
        choice = counselling.choices.find_or_initialize_by(institute: institutes.fetch(row["instcd"]), program: programs.fetch(row["brcd"]), quota: row["quota"])
        choice.update!(sr: row["sr"])
      end
      counselling
    end
  end
end
