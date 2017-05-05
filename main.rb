#!/usr/bin/env ruby

require 'i18n'
require 'fileutils'
require 'nokogiri'
require 'open-uri'
require 'id3_tags'
require 'dotenv/load'
require "curses"

include Curses

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
  @downloads_path = "downloads"

  def self.download_all
    main_body = Nokogiri::HTML(open_url(@base_url + @first_href))
    books = main_body.css(".bible-nav .large ul.dropdown-menu li").map(&:children).flatten.map{|i| i["href"]}

    progress_thread = start_progress_thread

    books.each do |book|
      Thread.new do
        Thread.current.thread_variable_set(:book?, true)
        book_body = Nokogiri::HTML(open_url(book))
        chapters = book_body.css(".bible-nav .small ul.dropdown-menu li>a").map{|i| i["href"]}
        folder = book_body.css(".bible-nav .large .btn.dropdown-toggle").first.text
        Thread.current.thread_variable_set(:folder, I18n.transliterate(folder))
        Thread.current.thread_variable_set(:chapters, chapters.size)
        dirs = []

        chapters.each.with_index do |chapter_url, index|
          chapter_body = Nokogiri::HTML(open_url(chapter_url))
          download_elem = chapter_body.css("audio > source[type='audio/mpeg']").first

          dirs << download_elem["src"]
          Thread.current.thread_variable_set(:progress, index + 1)
        end

        FileUtils.mkdir_p("#{@downloads_path}/#{folder}")

        Thread.current.thread_variable_set(:progress, 0)
        Thread.current.thread_variable_set(:downloading, true)
        dirs.each.with_index do |chapter_url, index|
          chapter = chapter_url.split('/').last.split('.')[1]
          File.open("#{@downloads_path}/#{folder}/#{folder} #{chapter}.mp3", "wb") do |f|
            f << open_url(chapter_url).read
          end

          Thread.current.thread_variable_set(:progress, chapter.to_i)
        end

        Thread.current.thread_variable_set(:progress, 0)
        Thread.current.thread_variable_set(:writing, true)
        Dir["#{@downloads_path}/#{folder}/*"].each.with_index do |file, index|
          chapter = file.gsub(".mp3", "").split(" ").last
          tags = {
            artist: "Bíblia",
            album: folder,
            title: "Capítulo #{chapter}"
          }
          Id3Tags.write_tags_to(file, tags)

          Thread.current.thread_variable_set(:progress, chapter)
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

  def self.start_progress_thread
    Thread.new do
      init_screen
      win = Window.new(lines, cols, 0, 0)

      while true
        break if Thread.current.thread_variable_get(:finish)

        running_threads.each do |p|
          folder = p.thread_variable_get(:folder)
          next unless folder
          progress = p.thread_variable_get(:progress) || 0
          downloading = p.thread_variable_get(:downloading)
          writing = p.thread_variable_get(:writing)
          chapters = p.thread_variable_get(:chapters)

          line = folder.truncate(12).ljust(13, " ")
          line += "|"
          progress_bar_size = progress.to_f / chapters.to_f * 50
          line += ("=" * progress_bar_size).ljust(50, " ")
          line += "| #{progress}/#{chapters} "

          if downloading
            line += "Downloading..."
          elsif writing
            line += "Writing..."
          else
            line += "Indexing..."
          end
          line += "\n"
          win.addstr line
        end
        win.refresh

        sleep 0.5
        win.clear
      end
      win.close
      close_screen
    end
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
