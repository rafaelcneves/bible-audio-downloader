#!/usr/bin/env ruby

require 'nokogiri'
require 'open-uri'
require 'fileutils'

class Bible
  @base_url = "http://www.biblica.com"
  @first_url = "/en-us/bible/online-bible/nvi-pt/ezequiel/1/"

  def self.create_download_files
    next_url = @base_url + @first_url
    Dir.mkdir('urls') unless Dir.exist?('urls')
    urls_dir = Dir.new('urls')

    while true
    # 5.times do
      body = Nokogiri::HTML(open(next_url))
      download_elem = body.css("audio > source[type='audio/mpeg']").first
      header_elem = body.css("h1").first

      puts header_elem.text
      folder = header_elem.text.gsub(/The\ Bible\: /, "").gsub(/\ \d*$/, "")

      filename = File.join(urls_dir, folder + ".txt")

      f = File.open(filename, "a")
      f.puts download_elem["src"]
      f.close

      next_elem = body.css(".next").first
      next_url = @base_url + next_elem["href"]
    end
  end

  def self.download_audios
    Dir[File.join(urls_dir, "*.txt")].each do |file|
      `wget --directory-prefix='download/#{file.split('/').last.gsub('.txt', '')}' -i #{file}`
    end
  end
end

Bible.create_download_files
Bible.download_audios
