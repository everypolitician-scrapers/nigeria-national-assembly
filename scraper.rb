#!/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'pry'
require 'scraped'
require 'scraperwiki'

require_rel './lib'

# require 'open-uri/cached'
# OpenURI::Cache.cache_path = '.cache'
require 'scraped_page_archive/open-uri'

class SearchPage < Scraped::HTML
  decorator Scraped::Response::Decorator::CleanUrls

  field :member_urls do
    noko.css('.search-result-item a').map { |a| a.attr('href') }
  end
end

member_urls = %w[a e i o u].flat_map do |vowel|
  url = 'http://www.nass.gov.ng/search/mps/?search=%s' % vowel
  SearchPage.new(response: Scraped::Request.new(url: url).response).member_urls
end.uniq

# The search index and list pages seem to be missing some members of
# the National Assembly, so add them manually to the pages to be scraped:
member_urls |= [
  'http://www.nass.gov.ng/mp/profile/91',  # Sen. LILIAN UCHE EKWUNIFE
  'http://www.nass.gov.ng/mp/profile/302', # Hon. CHINDA KINGSLEY OGUNDU
  'http://www.nass.gov.ng/mp/profile/306', # Hon. NSIEGBE BLESSING IBIBA
  'http://www.nass.gov.ng/mp/profile/506', # Sen. OHUABUNWA AZIKIWE MAO
  'http://www.nass.gov.ng/mp/profile/519', # Sen. HUSSAIN EGYE SALIHU
  'http://www.nass.gov.ng/mp/profile/520', # Sen. ABDUL ABDULRAHMAN ABUBAKAR
  'http://www.nass.gov.ng/mp/profile/527', # Hon. JACOBSON NBINA BARINEKA
  'http://www.nass.gov.ng/mp/profile/538', # Hon. DEKOR ROBINSON DUMNAMENE
  'http://www.nass.gov.ng/mp/profile/551', # Hon. HERMAN IORWASE HEMBE
  'http://www.nass.gov.ng/mp/profile/577', # Hon. PHILIP SHAIBU
  'http://www.nass.gov.ng/mp/profile/631', # Hon. EMERENGWA SUNDAY BONIFACE
  'http://www.nass.gov.ng/mp/profile/635', # Hon. Dennis Nnamdi Agbo
  'http://www.nass.gov.ng/mp/profile/646', # Hon. KWAMOTI BITRUS LAORI
  'http://www.nass.gov.ng/mp/profile/664', # Hon. BELLO ABDULLAHI
  'http://www.nass.gov.ng/mp/profile/675', # Hon. Betty Jocelyn Apiafi
  'http://www.nass.gov.ng/mp/profile/679', # Hon. SOPULUCHUKWU ELBERT EZEONWUKA
  'http://www.nass.gov.ng/mp/profile/729', # Hon. KHAMISU AHM MAILANTARKI AHMED
  'http://www.nass.gov.ng/mp/profile/758', # Sen. Isiaka Adetunji Adeleke
  'http://www.nass.gov.ng/mp/profile/809', # Sen. ATHANASIUS NNEJI ACHONU
  'http://www.nass.gov.ng/mp/profile/812', # Sen. OSINAKACHUKWU T IDEOZU
  'http://www.nass.gov.ng/mp/profile/826', # Hon. D Goodhead Boma
  'http://www.nass.gov.ng/mp/profile/831', # Hon. Jerome Eke
  'http://www.nass.gov.ng/mp/profile/836', # Hon. AWAJI-INOMBEK DAGOMIE ABIANTE
  'http://www.nass.gov.ng/mp/profile/839', # Hon. KENNETH ANAYO CHIKERE
  'http://www.nass.gov.ng/mp/profile/876', # Sen. GEORGE THOMPSON SEKIBO
  'http://www.nass.gov.ng/mp/profile/884', # Hon. GOGO BRIGHT TAMUNO
  'http://www.nass.gov.ng/mp/profile/891', # Sen. Ahmed .Salau Ogembe
  'http://www.nass.gov.ng/mp/profile/896', # Hon. BROWN RANDOLPH IWO ONYERE
  'http://www.nass.gov.ng/mp/profile/937', # Sen. OLAKA JOHNSON NWOGU
  'http://www.nass.gov.ng/mp/profile/952', # Hon. Ugwuegede Ikechukwu
]

def scrape(h)
  url, klass = h.to_a.first
  klass.new(response: Scraped::Request.new(url: url).response)
end

data = member_urls.map { |url| scrape(url => MemberPage).to_h.merge(term: 8) }
data.each { |mem| puts mem.reject { |_, v| v.to_s.empty? }.sort_by { |k, _| k }.to_h } if ENV['MORPH_DEBUG']

ScraperWiki.sqliteexecute('DROP TABLE data') rescue nil
ScraperWiki.save_sqlite(%i[id name term], data)
