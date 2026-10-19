require "csv"

class ListExport
  HEADERS = %w[rank institute_code institute state state_doubtful institute_type speciality course program_code program quota note].freeze

  def initialize(list)
    @list = list
  end

  def to_csv
    CSV.generate do |csv|
      csv << HEADERS
      @list.picks.includes(choice: %i[institute program]).each do |pick|
        institute = pick.choice.institute
        program = pick.choice.program
        csv << [pick.position, institute.code, institute.name, institute.state, institute.state_doubtful ? "yes" : "",
                institute.type_name, program.speciality, program.course, program.code, program.name, pick.choice.quota, pick.note]
      end
    end
  end
end
