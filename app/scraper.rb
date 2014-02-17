require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'awesome_print'

class Scraper

  def scrap_book_index
    base_url = "http://sunnah.com"
    url = "#{base_url}/abudawud"
    doc = Nokogiri::HTML(open(url))
    #ap doc.at_css(".colindextitle").text

    books = []

    doc.css(".book_title").each do |item|
      book = {
          book_url: (base_url + item.at_css("a")['href']),
          book_number: item.at_css(".book_number").text,
          book_name: {
              en: item.at_css(".english_book_name").text,
              ar: item.at_css(".arabic_book_name").text
          },
          book_range: item.css(".book_range_from").collect { |range| range.text }
      }
      books << book
    end

    #ap books
    scrap_book_page books.first[:book_url]
  end

  def scrap_book_page(url)
    doc = Nokogiri::HTML(open(url))
    hadiths = []

    doc.css(".actualHadithContainer").each do |item|
      hadith = {
          #book_url: (base_url + item.at_css("a")['href']),
          hadith_narrator: (item.at_css(".englishcontainer .hadith_narrated").text rescue nil),
          hadith: {
              en: (item.at_css(".englishcontainer .text_details").text rescue nil),
              ar: (item.at_css(".arabic_hadith_full .arabic_text_details").text rescue nil)
          },
          reference: dom_to_reference(item.at_css(".hadith_reference"))
          #book_range: item.css(".book_range_from").collect { |range| range.text }
      }
      hadiths << hadith
    end

    ap hadiths
  end


  def dom_to_reference(dom)
    dom.css("tr").collect do |item|
      items = item.css("td")
      ref_name = items.first.text rescue nil
      ref = items.last.text rescue nil
      {ref_name => ref[/\s*:\s+.*/]}
    end
  end

end

Scraper.new.scrap_book_index