namespace :icons do
  desc "Build app/assets/images/icons.svg from the Lucide SVGs in vendor/lucide"
  task :sprite do
    symbols = Dir[Rails.root.join("vendor/lucide/*.svg")].sort.map do |path|
      svg = File.read(path).gsub(/<!--.*?-->/m, "")
      body = svg[%r{<svg[^>]*>(.*)</svg>}m, 1].strip.gsub(/\s*\n\s*/, " ").gsub(/>\s+</, "><")
      %(<symbol id="#{File.basename(path, ".svg")}" viewBox="0 0 24 24">#{body}</symbol>)
    end
    sprite = %(<svg xmlns="http://www.w3.org/2000/svg" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">#{symbols.join}</svg>\n)
    File.write(Rails.root.join("app/assets/images/icons.svg"), sprite)
    puts "#{symbols.size} icons"
  end
end
