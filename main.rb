#!/usr/bin/env ruby

require 'nokogiri'
require 'open-uri'
# require 'fileutils'

class Bible
  @base_url = "http://www.biblica.com"
  @first_href = "/en-us/bible/online-bible/nvi-pt/genesis/1/"
  @urls_path = "urls"

  def self.create_download_files
    main_body = Nokogiri::HTML(open(@base_url + @first_href))
    books = main_body.css(".bible-nav .large ul.dropdown-menu li").map(&:children).flatten.map{|i| i["href"]}

    [0..9, 10..19, 20..29, 30..39, 40..49, 50..59, 60..65].each do |interval|
      books[interval].each do |book|
        fork do
          book_body = Nokogiri::HTML(open(@base_url + book))
          chapters = book_body.css(".bible-nav .small ul.dropdown-menu li").map(&:children).flatten.map{|i| i["href"]}
          folder = book_body.css(".bible-nav .large .btn.dropdown-toggle").first.text
          dirs = []

          chapters.each do |chapter|
            chapter_body = Nokogiri::HTML(open(@base_url + chapter))
            download_elem = chapter_body.css("audio > source[type='audio/mpeg']").first

            dirs << download_elem["src"]
            print "#"
          end

          filename = File.join(@urls_path, folder)
          File.open(filename, "w") do |file|
            file.puts dirs
          end
        end
      end
      Process.waitall
    end
  end

  def self.download_audios
    Dir[File.join(@urls_path, "*")].each do |file|
      puts file
      `wget -q --directory-prefix='downloads/#{file.split('/').last}' -i #{file}`
    end
  end
end

Bible.create_download_files
# Bible.download_audios
