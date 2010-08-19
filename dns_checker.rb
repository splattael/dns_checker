#!/usr/bin/env ruby

require 'rubygems'
require 'bundler'

Bundler.setup

require 'net/dns/resolver'
require 'term/ansicolor'

ROOT_NAMESERVER = "a.root-servers.net"

class String
  include Term::ANSIColor
end

class DNSChecker
  COLORS = {
    :fail => :red,
    :pass => :green,
    :warn => :yellow
  }

  def initialize(root_nameserver, local_nameserver)
    @root_nameserver = resolve_address(root_nameserver)
    @local_nameserver = resolve_address(local_nameserver)
    @tld_cache = {}
  end

  def resolve(domain, resolver=nil)
    resolver ||= Net::DNS::Resolver.new
    resolver.search(domain)
  end

  def resolve_at(domain, nameserver)
    resolver = Net::DNS::Resolver.new
    resolver.nameservers = nameserver
    resolver.search(domain)
  end

  def resolve_address(domain)
    resolve(domain).answer.first.address.to_s
  end

  def resolve_root_nameserver(domain)
    @tld_cache[tld(domain)] ||= extract_a(resolve_at(domain, @root_nameserver).additional)
  end

  def tld(domain)
    domain.split(/\./)[-1]
  end

  def extract_a(additional)
    additional.select { |a| Net::DNS::RR::A === a }.choice.address.to_s
  end

  def extract_ns(authority)
    authority.select { |a| Net::DNS::RR::NS === a }.map(&:nsdname).sort.first
  end

  def check(domain)
    nameserver = resolve_root_nameserver(domain)

    at_root = extract_ns(resolve_at(domain, nameserver).authority)
    local = extract_ns(resolve_at(domain, @local_nameserver).authority)

    if at_root != local
      write :fail, domain, "'#{at_root}' != '#{local}'"
    else
      write :pass, domain
    end
  rescue => e
    write :warn, domain, e
  end

  def write(type, domain, reason=nil)
    color = COLORS[type]
    reason = ": #{reason.to_s.cyan.bold}" if reason
    "#{type.to_s.upcase.send(color).bold} #{domain}#{reason}"
  end
end

# Main

if $0 == __FILE__
  local_nameserver = ARGV.shift or abort("usage: echo 'example.com' | #{$0} my-nameserver")
  checker = DNSChecker.new(ROOT_NAMESERVER, local_nameserver)

  STDIN.each do |domain|
    puts checker.check(domain.chomp)
  end
end
