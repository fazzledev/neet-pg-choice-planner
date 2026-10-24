require "zip"

class ExtensionPackage
  SOURCE = Rails.root.join("extension")
  FOLDER = "choice-planner-filler"
  CHROME_WEB_STORE_URL = "https://chromewebstore.google.com/detail/dknkamnnjakgmgggbeomoakajbkdennd"
  FIREFOX_ADD_ONS_URL = "https://addons.mozilla.org/firefox/addon/neet-pg-choice-plan-mcc-filler/"
  FIREFOX_LISTED = false

  def self.files
    SOURCE.glob("**/*").select(&:file?).sort
  end

  def self.version
    JSON.parse(SOURCE.join("manifest.json").read).fetch("version")
  end

  def self.zip
    @zip = nil if @zip_stamp != stamp
    @zip_stamp = stamp
    @zip ||= Zip::OutputStream.write_buffer do |zip|
      files.each do |path|
        zip.put_next_entry(path.relative_path_from(SOURCE).to_s)
        zip.write(path.binread)
      end
    end.string
  end

  def self.stamp
    files.map { |path| [path.to_s, path.mtime.to_f] }
  end
  private_class_method :stamp
end
