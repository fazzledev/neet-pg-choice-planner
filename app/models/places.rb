module Places
  STATES = [
    "Andaman and Nicobar Islands", "Andhra Pradesh", "Arunachal Pradesh", "Assam", "Bihar", "Chandigarh",
    "Chhattisgarh", "Dadra and Nagar Haveli", "Daman and Diu", "Delhi", "Goa", "Gujarat", "Haryana",
    "Himachal Pradesh", "Jammu and Kashmir", "Jharkhand", "Karnataka", "Kerala", "Ladakh", "Lakshadweep",
    "Madhya Pradesh", "Maharashtra", "Manipur", "Meghalaya", "Mizoram", "Nagaland", "Odisha", "Puducherry",
    "Punjab", "Rajasthan", "Sikkim", "Tamil Nadu", "Telangana", "Tripura", "Uttar Pradesh", "Uttarakhand",
    "West Bengal"
  ].freeze

  CITIES = {
    "Andaman and Nicobar Islands" => %w[Andaman Nicobar],
    "Andhra Pradesh" => %w[Guntur Kakinada Tirupati Vijayawada Ananthapuram Anantapur Kurnool Visakhapatnam Kadapa Ongole Srikakulam Vizianagaram Nandyal Nellore Eluru Machilipatnam Rajahmundry],
    "Assam" => %w[Guwahati Gauhati Silchar Jorhat Tezpur Barpeta Dibrugarh Lakhimpur Diphu Dhubri Nagaon],
    "Bihar" => %w[Patna Muzaffarpur Muzzafarpur Gaya Pawapuri Darbhanga Bhagalpur Bettiah Purnea Madhepura Nalanda],
    "Chhattisgarh" => %w[Raipur Bilaspur Jagdalpur Ambikapur Rajnandgaon Korba Raigarh Kanker Mahasamund],
    "Dadra and Nagar Haveli" => %w[Silvassa],
    "Delhi" => %w[Janakpuri Rohini Dwarka],
    "Gujarat" => %w[Surat Baroda Vadodara Jamnagar Bhavnagar Ahmedabad Rajkot Navsari Valsad Gandhinagar Bhuj Junagadh Himmatnagar Dharpur Patan],
    "Haryana" => %w[Nuh Mewati Rohtak Khanpur Karnal Faridabad Gurugram Gurgaon],
    "Himachal Pradesh" => %w[Shimla Tanda Mandi Nerchowk Hamirpur Chamba Nahan],
    "Jammu and Kashmir" => %w[Srinagar Jammu Anantnag Baramulla Kathua Rajouri Doda Udhampur],
    "Jharkhand" => %w[Jamshedpur Ranchi Dhanbad Hazaribagh Dumka Palamu],
    "Karnataka" => %w[Bellary Ballari Mysore Mysuru Bidar Raichur Hassan Shimoga Shivamogga Belagavi Belgaum Dharwad Gadag Gulbarga Kalaburagi Koppal Karwar Kodagu Mandya Hubballi Hubli Mangalore Chikkaballapur Chamarajanagar Kolar Chikkaballapura],
    "Kerala" => %w[Calicut Kozhikode Thrissur Alleppey Alappuzha Allappuzha Ernakulam Kollam Parippally Pariyaram Kannur Palakkad Kottayam Thiruvanthapuram Trivandrum Manjeri Idukki Konni Kasaragod Cochin],
    "Madhya Pradesh" => %w[Bhopal Gwalior Indore Jabalpur Rewa Sagar Vidisha Khandwa Satna Chhindwara Shahdol Datia Shivpuri Ratlam],
    "Maharashtra" => %w[Pune Solapur Nagpur Aurangabad Miraj Ambajogai Nanded Yavatmal Latur Akola Thane Pimpri Jalgaon Chandrapur Baramati Nandurbar Gondia Kolhapur Dhule Satara Alibag Sindhudurg Washim Wardha Sevagram],
    "Manipur" => %w[Imphal Porompet],
    "Meghalaya" => %w[Shillong],
    "Odisha" => %w[Berhampur Cuttack Burla Sambalpur Balasore Bolangir Koraput Baripada Keonjhar Bhubaneswar],
    "Punjab" => %w[Patiala Amritsar Faridkot Mohali],
    "Rajasthan" => %w[Jodhpur Ajmer Bikaner Jaipur Kota Udaipur Churu Dungarpur Barmer Bharatpur Bhilwara Pali Sikar Alwar Jhalawar],
    "Tamil Nadu" => %w[Coimbatore Madurai Thanjavur Tirunelveli Salem Chengalpattu Trichy Tiruchirappalli Theni Vellore Kanyakumari Asaripallam Thoothukudi Villupuram Thiruvarur Cuddalore Omandurar Tiruvannamalai Thiruvannamalai Sivagangai Erode Karur Pudukkottai Dharmapuri Ramanathapuram Virudhunagar Namakkal Tiruppur Nagapattinam Krishnagiri Kallakurichi Ariyalur Dindigul Nilgiris] + ["T.N", "TamilNadu"],
    "Telangana" => %w[Warangal Siddipet Nalgonda Suryapet Ramagundam Gachibowli Secunderabad Nizamabad Mahabubnagar Khammam Sangareddy Jagtial Nagarkurnool Mancherial Wanaparthy Kothagudem],
    "Tripura" => %w[Agartala],
    "Uttar Pradesh" => %w[Varanasi Varansi Lucknow Aligarh Meerut Jhansi Allahabad Prayagraj Agra Noida Saharanpur Gorakhpur Banda Shahjahanpur Firozabad Siddharthnagar Hardoi Pratapgarh Faizabad Ayodhya Basti Kanpur Bahraich Azamgarh Jaunpur Etah Ghazipur Mirzapur Sitapur Bareilly Moradabad Kannauj Badaun Deoria Fatehpur Lalitpur Sultanpur Gonda] + ["UP", "U.P"],
    "Uttarakhand" => %w[Uttaranchal Rudrapur Haldwani Almora Srinagar\ Garhwal Pauri Dehradun Haridwar],
    "West Bengal" => %w[Darjeeling Bankura Midnapore Murshidabad Malda Burdwan Bardhaman Siliguri Kalyani Purulia Raiganj Cooch Rampurhat Diamond Jhargram Tamluk Barasat Arambagh Uluberia]
  }.freeze

  ALIASES = {
    "Pondicherry" => "Puducherry", "Orissa" => "Odisha", "New Delhi" => "Delhi", "Bombay" => "Maharashtra",
    "Mumbai" => "Maharashtra", "Navi Mumbai" => "Maharashtra", "Chennai" => "Tamil Nadu", "Bangalore" => "Karnataka",
    "Bengaluru" => "Karnataka", "Hyderabad" => "Telangana", "Kolkata" => "West Bengal",
    "Thiruvananthapuram" => "Kerala", "Kochi" => "Kerala", "MP" => "Madhya Pradesh", "M.P" => "Madhya Pradesh",
    "H.P" => "Himachal Pradesh", "Maharasthtra" => "Maharashtra", "Panaji" => "Goa", "Chandigarh" => "Chandigarh"
  }.merge(CITIES.flat_map { |state, cities| cities.map { [_1, state] } }.to_h).freeze

  AMBIGUOUS = %w[Srinagar Aurangabad Bilaspur Hamirpur Pratapgarh Raigarh Patan Pali Banda Mandi Diamond Cooch UP MP U.P M.P H.P].freeze

  def self.pattern(needle)
    /(?<![A-Za-z])#{Regexp.escape(needle)}(?![A-Za-z])/i
  end

  STATE_NEEDLES = STATES.map { [pattern(_1), _1, _1, true] }.freeze
  ALIAS_NEEDLES = ALIASES.map { |needle, state| [pattern(needle), state, needle, false] }.freeze

  def self.locate(text)
    hits = (STATE_NEEDLES + ALIAS_NEEDLES).filter_map do |re, state, needle, official|
      (at = text.rindex(re)) && { at: at, len: needle.length, state: state, needle: needle, official: official }
    end
    official = hits.select { _1[:official] }
    if official.any?
      best = official.max_by { [_1[:at], _1[:len]] }
      return [best[:state], official.map { _1[:state] }.uniq.size > 1]
    end
    return [nil, true] if hits.empty?

    best = hits.max_by { [_1[:at], _1[:len]] }
    doubtful = hits.map { _1[:state] }.uniq.size > 1 || hits.all? { AMBIGUOUS.include?(_1[:needle]) }
    [best[:state], doubtful]
  end

  def self.state_for(text)
    locate(text).first
  end
end
