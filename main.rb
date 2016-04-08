#!/usr/bin/env ruby

require 'nokogiri'
require 'open-uri'
# require 'fileutils'

class Bible
  @base_url = "http://www.biblica.com"
  @first_url = "/en-us/bible/online-bible/nvi-pt/genesis/1/"
  @urls_path = "urls"

  def self.create_download_files
    next_url = @base_url + @first_url
    dirs = []

    while true
      body = Nokogiri::HTML(open(next_url))
      download_elem = body.css("audio > source[type='audio/mpeg']").first
      folder = next_url.split("/")[-2]

      print folder + " " if dirs.empty?

      dirs << download_elem["src"]
      print "#"

      next_elem = body.css(".next").first
      next_url = @base_url + next_elem["href"]
      next_folder = next_url.split("/")[-2]

      unless next_folder == folder
        filename = File.join(@urls_path, folder)

        File.open(filename, "w") do |file|
          file.puts dirs
        end

        dirs = []
        print "\n"
      end
    end
  end

  def self.download_audios
    Dir[File.join(@urls_path, "*")].each do |file|
      `wget --directory-prefix='downloads/#{file.split('/').last}' -i #{file}`
    end
  end
end

Bible.create_download_files
Bible.download_audios
