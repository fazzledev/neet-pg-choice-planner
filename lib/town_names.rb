module TownNames
  RENAMES = [
    %w[Bengaluru Bangalore], %w[Mysuru Mysore], %w[Mangaluru Mangalore], %w[Belagavi Belgaum], %w[Kalaburagi Gulbarga],
    %w[Ballari Bellary], %w[Shivamogga Shimoga], %w[Hubballi Hubli], %w[Vijayapura Bijapur], %w[Tumakuru Tumkur],
    %w[Prayagraj Allahabad], %w[Gurugram Gurgaon], %w[Vadodara Baroda],
    ["Chhatrapati Sambhajinagar", "Aurangabad"], %w[Ahilyanagar Ahmednagar], %w[Dharashiv Osmanabad],
    ["Sri Vijaya Puram", "Port Blair"], %w[Thiruvananthapuram Trivandrum], %w[Kozhikode Calicut], %w[Kochi Cochin],
    %w[Puducherry Pondicherry], %w[Thoothukudi Tuticorin], %w[Tiruchirappalli Trichy], %w[Brahmapur Berhampur],
    %w[Baharampur Berhampore], %w[Rajamahendravaram Rajahmundry], %w[Bardhaman Burdwan], %w[Medinipur Midnapore],
    %w[Purnia Purnea], %w[Chhapra Chapra], %w[Budaun Badaun], %w[Kancheepuram Kanchipuram], %w[Tiruvallur Thiruvallur],
    %w[Palai Pala], %w[Anantapur Ananthapuram Anantapuramu], %w[Tiruvannamalai Thiruvannamalai], %w[Krishnanagar Krishnagar], %w[Thrissur Trichur], %w[Kollam Quilon], %w[Alappuzha Alleppey],
    %w[Nashik Nasik], %w[Bhubaneswar Bhubaneshwar],
  ].freeze

  def self.group(town) = RENAMES.find { |names| names.any? { _1.casecmp?(town.to_s) } }
  def self.key(town) = (group(town)&.first || town).to_s.downcase.gsub(/[^a-z]/, "")

  def self.consonants(town) = key(town).delete("aeiouh").squeeze

  def self.same_place?(a, b)
    return false if key(a).empty? || key(b).empty?

    key(a) == key(b) || consonants(a) == consonants(b)
  end
end
