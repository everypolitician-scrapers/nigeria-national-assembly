#!/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'colorize'
require 'field_serializer'
require 'nokogiri'
require 'pry'
require 'scraperwiki'

# require 'open-uri/cached'
# OpenURI::Cache.cache_path = '.cache'

require 'scraped_page_archive/open-uri'

class String
  def tidy
    gsub(/[[:space:]]+/, ' ').strip
  end
end

class Page
  include FieldSerializer

  def initialize(url)
    @url = url
  end

  def noko
    @noko ||= Nokogiri::HTML(open(url).read)
  end

  private

  attr_reader :url
end

class SearchPage < Page
  field :members do
    noko.css('.search-result-item a').map do |a|
      {
        name: a.text,
        url:  URI.join(url, a.attr('href')),
      }
    end
  end

  field :url do
    @url
  end

  private

  attr_reader :search_string
end

class MemberPage < Page
  field :id do
    url.to_s.split('/').last
  end

  TITLE_RE = /^(Hon\.|Sen\.) /

  field :name do
    name_with_title.gsub(TITLE_RE, '')
  end

  field :title do
    name_with_title[TITLE_RE, 1]
  end

  field :constituency do
    constituency
  end

  field :state do
    state
  end

  field :chamber do
    box.xpath('.//th[text()="Chamber"]/following-sibling::td').text.tidy
  end

  field :party do
    party
  end

  field :party_id do
    party_id
  end

  field :image do
    img = box.css('.carousel-inner img/@src').text
    return if img.to_s.empty?
    URI.join(url, img).to_s
  end

  field :term do
    2015
  end

  field :source do
    url.to_s
  end

  field :area do
    [constituency, state].join(', ')
  end

  field :phone do
    noko.css('.fa-phone').xpath('./following-sibling::text()').first.text.tidy
  end

  private

  def name_with_title
    box.xpath('.//th[text()="Name"]/following-sibling::td').text.tidy
  end

  def box
    noko.css('.front-carousel')
  end

  def party_node
    box.xpath('.//th[text()="Party"]/following-sibling::td').text
  end

  def party_node_match
    party_node.match(/^(.*)\s+\((.*)\)\s*$/) || abort("Bad party: #{party_node}")
  end

  def party
    party_node_match.captures.first
  end

  def party_id
    party_node_match.captures.last
  end

  def constituency
    box.xpath('.//th[text()="Constituency"]/following-sibling::td').text.tidy
  end

  def state
    box.xpath('.//th[text()="State"]/following-sibling::td').text.tidy
  end
end

members = %w(a e i o u).flat_map do |vowel|
  url = 'http://www.nass.gov.ng/search/mps/?search=%s' % vowel
  SearchPage.new(url).to_h[:members]
end.uniq

members.each do |mem|
  person = MemberPage.new(mem[:url])
  ScraperWiki.save_sqlite(%i(id name term chamber), person.to_h)
end
