#!/usr/bin/env ruby

require 'nokogiri'
require 'open-uri'

class Bible
  @base_url = "http://www.biblica.com"
  @first_href = "/en-us/bible/online-bible/nvi-pt/genesis/1/"
  @urls_path = "urls"

  def self.create_download_files
    main_body = Nokogiri::HTML(open(@base_url + @first_href))
    books = main_body.css(".bible-nav .large ul.dropdown-menu li").map(&:children).flatten.map{|i| i["href"]}
    process = []

    progress = Thread.new do
      while true
        system "clear"
        Thread.current.thread_variable_get(:process).each do |p|
          begin
            puts p.thread_variable_get(:folder) + " " + p.thread_variable_get(:progress)
          rescue
          end
        end
        sleep 1
        break if Thread.current.thread_variable_get(:finish)
      end
    end

    books.each do |book|
      process << Thread.new do
        book_body = Nokogiri::HTML(open(@base_url + book))
        chapters = book_body.css(".bible-nav .small ul.dropdown-menu li").map(&:children).flatten.map{|i| i["href"]}
        folder = book_body.css(".bible-nav .large .btn.dropdown-toggle").first.text
        Thread.current.thread_variable_set(:folder, folder)
        dirs = []

        chapters.each do |chapter|
          chapter_body = Nokogiri::HTML(open(@base_url + chapter))
          download_elem = chapter_body.css("audio > source[type='audio/mpeg']").first

          dirs << download_elem["src"]
          Thread.current.thread_variable_set(:progress, "#{chapter.split('/').last}/#{chapters.size}")
        end

        filename = File.join(@urls_path, folder)
        File.open(filename, "w") do |file|
          file.puts dirs
        end
      end

      progress.thread_variable_set(:process, process)

      while process.size >= 10 do
        process.each do |p|
          unless p.status
            process.delete(p)
          end
        end
        sleep 1
      end
    end

    process.each(&:join)
    progress.thread_variable_set(:finish, true)
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
