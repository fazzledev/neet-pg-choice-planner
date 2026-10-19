module ProgramName
  COURSES = ["MD", "MS", "DNB", "DNB 6-yr", "DNB Diploma", "Diploma"].freeze

  SPECIALITIES = {
    "anaesthesiology" => "Anaesthesiology",
    "anatomy" => "Anatomy",
    "bio chemistry" => "Biochemistry",
    "biochemistry" => "Biochemistry",
    "cardio vascular and thoracic surgery" => "Cardiothoracic Surgery",
    "community medicine" => "Community Medicine",
    "community medicine social and preventive medicine" => "Community Medicine",
    "dermatology venereology and leprosy" => "Dermatology",
    "dermatology venereology and leprosy dermatology" => "Dermatology",
    "emergency medicine" => "Emergency Medicine",
    "family medicine" => "Family Medicine",
    "forensic medicine" => "Forensic Medicine",
    "forensic medicine and toxicology forensic medicine" => "Forensic Medicine",
    "general medicine" => "General Medicine",
    "general surgery" => "General Surgery",
    "geriatric medicine" => "Geriatrics",
    "geriatrics" => "Geriatrics",
    "hospital administration" => "Hospital Administration",
    "health administration" => "Health Administration",
    "community health admn" => "Health Administration",
    "immunohematology and blood transfusion" => "Blood Transfusion",
    "immuno haematology and blood transfusion" => "Blood Transfusion",
    "laboratory medicine" => "Laboratory Medicine",
    "master of public health epidemiology" => "Public Health",
    "public health" => "Public Health",
    "microbiology" => "Microbiology",
    "neuro surgery" => "Neurosurgery",
    "nuclear medicine" => "Nuclear Medicine",
    "radiation medicine" => "Nuclear Medicine",
    "obstetrics and gynaecology" => "Obstetrics & Gynaecology",
    "ophthalmology" => "Ophthalmology",
    "orthopaedics" => "Orthopaedics",
    "otorhinolaryngology" => "ENT",
    "otorhinolaryngology ent" => "ENT",
    "ent" => "ENT",
    "paediatric surgery" => "Paediatric Surgery",
    "paediatrics" => "Paediatrics",
    "palliative medicine" => "Palliative Medicine",
    "pathology" => "Pathology",
    "clinical pathology" => "Pathology",
    "pharmacology" => "Pharmacology",
    "physical medicine and rehabilitation" => "Physical Medicine & Rehabilitation",
    "physiology" => "Physiology",
    "plastic and reconstructive surgery" => "Plastic Surgery",
    "psychiatry" => "Psychiatry",
    "radiation oncology" => "Radiation Oncology",
    "radiation oncology radiotherapy" => "Radiation Oncology",
    "radio diagnosis" => "Radiodiagnosis",
    "radiodiagnosis" => "Radiodiagnosis",
    "radio diagnosis radiology" => "Radiodiagnosis",
    "respiratory medicine" => "Respiratory Medicine",
    "respiratory medicine tuberculosis and respiratory diseases" => "Respiratory Medicine",
    "tuberculosis and chest disease" => "Respiratory Medicine",
    "tuberculosis and chest diseases" => "Respiratory Medicine",
    "sport medicine" => "Sports Medicine",
    "sports medicine" => "Sports Medicine",
    "traumatology and surgery" => "Traumatology & Surgery",
    "tropical medicine" => "Tropical Medicine"
  }.freeze

  ICONS = {
    "Anaesthesiology" => "syringe",
    "Anatomy" => "person-standing",
    "Biochemistry" => "flask-conical",
    "Blood Transfusion" => "droplet",
    "Cardiothoracic Surgery" => "heart-pulse",
    "Community Medicine" => "users",
    "Dermatology" => "hand",
    "ENT" => "ear",
    "Emergency Medicine" => "siren",
    "Family Medicine" => "house-heart",
    "Forensic Medicine" => "scale",
    "General Medicine" => "stethoscope",
    "General Surgery" => "bandage",
    "Geriatrics" => "hand-heart",
    "Health Administration" => "clipboard-list",
    "Hospital Administration" => "hospital",
    "Laboratory Medicine" => "test-tubes",
    "Microbiology" => "bug",
    "Neurosurgery" => "brain",
    "Nuclear Medicine" => "atom",
    "Obstetrics & Gynaecology" => "venus",
    "Ophthalmology" => "eye",
    "Orthopaedics" => "bone",
    "Paediatric Surgery" => "baby",
    "Paediatrics" => "baby",
    "Palliative Medicine" => "heart-handshake",
    "Pathology" => "microscope",
    "Pharmacology" => "pill",
    "Physical Medicine & Rehabilitation" => "accessibility",
    "Physiology" => "activity",
    "Plastic Surgery" => "sparkles",
    "Psychiatry" => "brain-cog",
    "Public Health" => "globe",
    "Radiation Oncology" => "radiation",
    "Radiodiagnosis" => "scan",
    "Respiratory Medicine" => "wind",
    "Sports Medicine" => "dumbbell",
    "Traumatology & Surgery" => "ambulance",
    "Tropical Medicine" => "tree-palm"
  }.freeze

  DEFAULT_ICON = "stethoscope"

  def self.icon_for(speciality)
    ICONS.fetch(speciality, DEFAULT_ICON)
  end

  def self.classify(name)
    course, rest =
      case name
      when /\A\(NBEMS\)\s*(.+?)\s*\(DIRECT 6 YEARS COURSE\)\z/i then ["DNB 6-yr", $1]
      when /\A\(NBEMS\)\s*(.+)\z/i then ["DNB", $1]
      when /\A\(NBEMS-DIPLOMA\)\s*(.+)\z/i then ["DNB Diploma", $1]
      when /\AM\.D\.\s*\(?(.+?)\)?\z/i then ["MD", $1]
      when /\AM\.S\.\s*(.+)\z/i then ["MS", $1]
      when /\ADiploma in\s+(.+)\z/i then ["Diploma", $1]
      when /\(D\.[A-Z.]+\)\z/ then ["Diploma", name]
      else [nil, name]
      end
    key = rest.sub(/\s*\([A-Za-z.]+\)\z/, "").downcase.gsub(/[^a-z]+/, " ").strip
    [course, SPECIALITIES[key]]
  end
end
