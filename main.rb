#!/usr/bin/env ruby

require 'nokogiri'
require 'open-uri'

class String
  def truncate length = 30, truncate_string = "..."
    if self.nil? then return end
    l = length - truncate_string.chars.to_a.size
    (self.chars.to_a.size > length ? self.chars.to_a[0...l].join + truncate_string : self).to_s
  end
end

class Bible
  @base_url = "http://www.biblica.com"
  @first_href = "/en-us/bible/online-bible/nvi-pt/genesis/1/"
  @urls_path = "urls"

  def self.create_download_files
    main_body = Nokogiri::HTML(open(@base_url + @first_href, proxy_http_basic_authentication: ["http://anoat.ht.lan:3128/", "rafael.neves", "ht@123AAA"]))
    books = main_body.css(".bible-nav .large ul.dropdown-menu li").map(&:children).flatten.map{|i| i["href"]}

    progress_thread = Thread.new do
      while true
        break if Thread.current.thread_variable_get(:finish)
        system "clear"
        running_threads.each do |p|
          folder = p.thread_variable_get(:folder)
          next unless folder
          progress = p.thread_variable_get(:progress)
          chapters = p.thread_variable_get(:chapters)
          print "#{folder.truncate(12).ljust(13, " ")}"
          print "| #{(("=" * (progress.to_f/chapters.to_f*50)) + ">").ljust(51, " ")} | #{progress}/#{chapters}" if progress
          print "\n"
        end
        sleep 0.5
      end
    end

    books.each do |book|
      Thread.new do
        Thread.current.thread_variable_set(:book?, true)
        book_body = Nokogiri::HTML(open(@base_url + book, proxy_http_basic_authentication: ["http://anoat.ht.lan:3128/", "rafael.neves", "ht@123AAA"]))
        chapters = book_body.css(".bible-nav .small ul.dropdown-menu li").map(&:children).flatten.map{|i| i["href"]}
        folder = book_body.css(".bible-nav .large .btn.dropdown-toggle").first.text
        Thread.current.thread_variable_set(:folder, folder)
        Thread.current.thread_variable_set(:chapters, chapters.size)
        dirs = []

        chapters.each do |chapter|
          chapter_body = Nokogiri::HTML(open(@base_url + chapter, proxy_http_basic_authentication: ["http://anoat.ht.lan:3128/", "rafael.neves", "ht@123AAA"]))
          download_elem = chapter_body.css("audio > source[type='audio/mpeg']").first

          dirs << download_elem["src"]
          Thread.current.thread_variable_set(:progress, chapter.split('/').last)
        end

        filename = File.join(@urls_path, folder)
        File.open(filename, "w") do |file|
          file.puts dirs
        end
      end

      begin
        sleep 1
      end until running_threads.size < 10
    end

    running_threads.each(&:join)
    progress_thread.thread_variable_set(:finish, true)
    progress_thread.join
  end

  def self.running_threads
    Thread.list.select {|thread| thread.status && thread.thread_variable_get(:book?) }
  end

  def self.download_audios
    Dir[File.join(@urls_path, "*")].each do |file|
      puts file.split('/').last
      `wget -q --directory-prefix='downloads/#{file.split('/').last}' -i #{file}`
    end
  end

end

Bible.create_download_files
# Bible.download_audios
