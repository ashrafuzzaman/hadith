require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'awesome_print'
require 'json'
require 'yaml'
require 'sqlite3'

class Scraper
  BASE_URL = "http://sunnah.com"

  def initialize
    @collection_id = 1
  end

  def scrap_collections
    clear_db
    scrap_collection("bukhari", 'Sahih al-Bukhari')
    scrap_collection("muslim", 'Sahih Muslim')
    scrap_collection("nasai", "Sunan an-Nasa'i")
    scrap_collection("abudawud", 'Sunan Abi Dawud')
    scrap_collection("tirmidhi", 'Jami` at-Tirmidhi')
    scrap_collection("ibnmajah", 'Sunan Ibn Majah')
    scrap_collection("malik", 'Muwatta Malik')
    scrap_collection("nawawi40", '40 Hadith Nawawi')
    scrap_collection("adab", 'Al-Adab Al-Mufrad')
  end

  def scrap_collection(book_name, readable_name)
    url = "#{BASE_URL}/#{book_name}"
    create_directory book_name
    collection_id = create_collection_in_db(readable_name, url)
    ap "Loading collection #{readable_name}"
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
    books.each_with_index do |book, i|
      create_book_in_db(i+1, collection_id, book)
      scrap_collection_page book[:book_url], "#{book_name}/#{i+1}"
    end
  end

  def clear_db
    ['collections', 'books', 'hadiths'].each do |table|
      db.execute("DELETE FROM #{table}")
    end
  end

  def create_collection_in_db(readable_name, url)
    insert_into('collections', id: @collection_id, name: readable_name, url: url)
    @collection_id += 1
    @collection_id - 1
  end

  def create_book_in_db(id, collection_id, book)
    insert_into('books', id: id,
                collection_id: collection_id,
                book_number: book[:book_number],
                book_name_en: book[:book_name][:en],
                book_name_ar: book[:book_name][:ar],
                book_range_from: book[:book_range][0],
                book_range_to: book[:book_range][1],
                url: book[:book_url])
  end

  def insert_into(table, data)
    fields = data.keys.collect(&:to_s).join(', ')
    qs = (1..data.size).collect { '?' }.join(',')
    query = "INSERT INTO #{table}(#{fields}) VALUES (#{qs})"
    db.execute(query, data.values.collect { |v| (v.nil? || !v.respond_to?(:strip)) ? v : v.strip })
  end

  def db
    @db ||= SQLite3::Database.new("hadith.db")
  end

  def scrap_collection_page(url, file_path)
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
          grade: {
              en: (item.css(".english_grade").last.text.strip.match(/\:\S?(.*)/)[1] rescue nil),
              ar: (item.at_css(".arabic_grade.arabic").text.strip rescue nil)
          },
          reference: dom_to_reference(item.at_css(".hadith_reference"))
      }
      hadiths << hadith
    end

    #marshal_to_file(file_path, hadiths)
  end

  def open_url(url, file_path)
    file_path = "#{file_path}.html"
    file_content = file_content(file_path)
    if file_content
      file_content
    else
      sleep rand(10)
      p "Fetching from web #{url}"
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

Scraper.new.scrap_collections