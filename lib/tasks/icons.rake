namespace :icons do
  desc "Build app/assets/images/icons.svg from the Lucide SVGs in vendor/lucide and the brand logos in vendor/simple-icons"
  task :sprite do
    symbol_body = lambda do |path|
      svg = File.read(path).gsub(/<!--.*?-->/m, "").gsub(%r{<title>.*?</title>}m, "")
      svg[%r{<svg[^>]*>(.*)</svg>}m, 1].strip.gsub(/\s*\n\s*/, " ").gsub(/>\s+</, "><")
    end
    lucide = Dir[Rails.root.join("vendor/lucide/*.svg")].sort.map do |path|
      %(<symbol id="#{File.basename(path, ".svg")}" viewBox="0 0 24 24">#{symbol_body.(path)}</symbol>)
    end
    brands = Dir[Rails.root.join("vendor/simple-icons/*.svg")].sort.map do |path|
      %(<symbol id="#{File.basename(path, ".svg")}" viewBox="0 0 24 24"><g fill="currentColor" stroke="none">#{symbol_body.(path)}</g></symbol>)
    end
    symbols = lucide + brands
    sprite = %(<svg xmlns="http://www.w3.org/2000/svg" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">#{symbols.join}</svg>\n)
    File.write(Rails.root.join("app/assets/images/icons.svg"), sprite)
    puts "#{symbols.size} icons"
  end
end
