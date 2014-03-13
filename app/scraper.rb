require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'awesome_print'
require 'json'
require 'yaml'

class Scraper
  BASE_URL = "http://sunnah.com"

  def scrap_books
    scrap_book("bukhari")
    scrap_book("muslim")
    scrap_book("nasai")
    scrap_book("abudawud")
    scrap_book("tirmidhi")
    scrap_book("ibnmajah")
    scrap_book("malik")
    scrap_book("nawawi40")
    scrap_book("adab")
  end

  def scrap_book(book_name)
    url = "#{BASE_URL}/#{book_name}"
    create_directory book_name
    doc = Nokogiri::HTML(open_url(url, book_name))

    books = []
    doc.css(".book_title").each do |item|
      book = {
          book_url: (BASE_URL + item.at_css("a")['href']),
          book_number: item.at_css(".book_number").text,
          book_name: {
              en: item.at_css(".english_book_name").text,
              ar: item.at_css(".arabic_book_name").text
          },
          book_range: item.css(".book_range_from").collect { |range| range.text }
      }
      books << book
    end
    marshal_to_file(book_name, books)
    books.each_with_index do |book, i|
      scrap_book_page book[:book_url], "#{book_name}/#{i+1}"
    end
  end

  def scrap_book_page(url, file_path)
    doc = Nokogiri::HTML(open_url(url, file_path))
    hadiths = []

    doc.css(".actualHadithContainer").each do |item|
      hadith = {
          hadith_narrator: (item.at_css(".englishcontainer .hadith_narrated").text.strip rescue nil),
          arabic_sanad: (item.at_css(".arabic_hadith_full .arabic_sanad").text.strip rescue nil),
          hadith: {
              en: (item.at_css(".englishcontainer .text_details").text.strip rescue nil),
              ar: (item.at_css(".arabic_hadith_full .arabic_text_details").text.strip rescue nil)
          },
          reference: dom_to_reference(item.at_css(".hadith_reference"))
      }
      hadiths << hadith
    end

    marshal_to_file(file_path, hadiths)
  end

  def open_url(url, file_path)
    file_path = "#{file_path}.html"
    file_content = file_content(file_path)
    if file_content
      p "Fetching from file #{file_path}"
      file_content
    else
      sleep rand(10)
      content = open(url).read
      write_to_file file_path, content
      content
    end
  end

  def dom_to_reference(dom)
    dom.css("tr").collect do |item|
      items = item.css("td")
      ref_name = items.first.text rescue nil
      ref = items.last.text.scan(/\s*:\s*(.*)/).flatten[0].strip rescue nil
      {ref_name => ref}
    end
  end

  def marshal_to_file(file_path, data)
    formats = ['json', 'yaml']
    formats.each do |format|
      write_to_file "#{file_path}.#{format.to_s}", data.send(:"to_#{format.to_s}")
    end
  end

  def file_content(file_path)
    path = File.expand_path "#{__FILE__}/../../books/#{file_path}"
    if File.exist?(path)
      File.open(path, "rb").read
    else
      nil
    end
  end

  def write_to_file(file_path, content)
    path = File.expand_path "#{__FILE__}/../../books/#{file_path}"
    p "Writting to file #{path}"
    File.open(path, "w") do |f|
      f.write(content)
    end
  end

  def create_directory(book_name)
    path = File.expand_path "#{__FILE__}/../../books/#{book_name}"
    Dir.mkdir path unless Dir.exist?(path)
  end
end

Scraper.new.scrap_books