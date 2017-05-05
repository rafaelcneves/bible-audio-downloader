#!/usr/bin/env ruby

require 'nokogiri'
require 'open-uri'
require 'id3_tags'
require 'dotenv/load'

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

  def self.download_all
    main_body = Nokogiri::HTML(open_url(@base_url + @first_href))
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
          downloading = p.thread_variable_get(:downloading)
          writing = p.thread_variable_get(:writing)
          print folder.truncate(12).ljust(12, " ")
          if progress
            print " | "
            unless downloading
              progress_bar_size = progress.to_f / chapters.to_f * 50
              progress_bar = ""
              progress_bar += ">" unless progress_bar_size < 1
              print progress_bar.
                rjust(progress_bar_size, "=").
                ljust(50, " ")
            else
              unless writing
                print "Downloading...".ljust(50, " ")
              else
                print "Writing...".ljust(50, " ")
              end
            end
            print " | "
            print "#{progress}/#{chapters}"
          end
          print "\n"
        end
        sleep 0.5
      end
    end

    books.each do |book|
      Thread.new do
        Thread.current.thread_variable_set(:book?, true)
        book_body = Nokogiri::HTML(open_url(book))
        chapters = book_body.css(".bible-nav .small ul.dropdown-menu li>a").map{|i| i["href"]}
        folder = book_body.css(".bible-nav .large .btn.dropdown-toggle").first.text
        Thread.current.thread_variable_set(:folder, folder)
        Thread.current.thread_variable_set(:chapters, chapters.size)
        dirs = []

        chapters.each do |chapter|
          chapter_body = Nokogiri::HTML(open_url(chapter))
          download_elem = chapter_body.css("audio > source[type='audio/mpeg']").first

          dirs << download_elem["src"]
          Thread.current.thread_variable_set(:progress, chapter.split('/').last)
        end

        filename = File.join(@urls_path, folder)
        File.open(filename, "w") do |file|
          file.puts dirs
        end

        Thread.current.thread_variable_set(:downloading, true)
        `wget -q --directory-prefix='downloads/#{folder}' -i '#{filename}'`

        Thread.current.thread_variable_set(:writing, true)
        Dir["downloads/#{folder}/*"].each do |file|
          chapter = file.split(".")[1]
          tags = {
            artist: "Bíblia",
            album: folder,
            title: "Capítulo #{chapter}"
          }
          Id3Tags.write_tags_to(file, tags)

          File.rename(file, "downloads/#{folder}/#{folder} #{chapter}.mp3")
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

  def self.open_url(url)
    options = {}
    if ENV['ENABLE_PROXY']
      options[:proxy_http_basic_authentication] = [
        ENV['PROXY_HOSTNAME'],
        ENV['PROXY_USERNAME'],
        ENV['PROXY_PASSWORD']
      ]
    end
    open url, options
  end

end

Bible.download_all
