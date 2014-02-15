require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'awesome_print'

class Scraper

  def scrap_title
    page = Nokogiri::HTML(open("http://hdith.com/abudawud"))
    puts page.class # => Nokogiri::HTML::Document
    ap page.css('.book_title')
  end

end


Scraper.new.scrap_title