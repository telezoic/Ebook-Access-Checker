# Tested in JRuby 1.7.3
# Written by Kristina Spurgin

# Usage:
# jruby -S EAC-VIUedits.rb [inputfilelocation] [outputfilelocation]

# Input file: 
# .csv file with: 
# - one header row
# - any number of columns to left of final column
# - one URL in final column

# Output file: 
# .csv file with all the data from the input file, plus a new column containing
#  access checker result

require 'celerity'
require 'csv'
require 'highline/import'
require 'open-uri'

  puts "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
  puts "What platform/package are you access checking?"
  puts "Type one of the following:"
  puts "  apb    : Apabi ebooks"
  puts "  asp    : Alexander Street Press links"
  puts "  curio  : Curio Collection at CBC" 
  puts "  duphw  : Duke University Press (via HighWire)"
  puts "  ebr    : Ebrary links"
  puts "  ebs    : EBSCOhost ebook collection"
  puts "  end    : Endeca - Check for undeleted records"
  puts "  fmgfod : FMG Films on Demand"
  puts "  jstor  : Books at JSTOR" #DDA 
  puts "  muse   : Project Muse" 
  puts "  nccorv : NCCO - Check for related volumes"
  puts "  sabov  : Sabin Americana - Check for Other Volumes"
  puts "  scid   : ScienceDirect ebooks (Elsevier)"
  puts "  spr    : SpringerLink links"
  puts "  skno   : SAGE Knowledge links"
  puts "  srmo   : SAGE Research Methods Online links"
  puts "  ss     : SerialsSolutions links"
  puts "  upso   : University Press (inc. Oxford) Scholarship Online links"
  puts "  wol    : Wiley Online Library"
  puts "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="

  #added VIU vendors: Curio/Muse/Jstor/ + some edits to existing vendor syntax + sleeps

  package = ask("Package?  ")

puts "\nPreparing to check access...\n"
start = Time.now #start of run time counter for benchmarking
input = ARGV[0]
output = ARGV[1]

csv_data = CSV.read(input, :headers => true)

counter = 0
total = csv_data.count

headers = csv_data.headers
headers << "access"

CSV.open(output, "a") do |c|
  c << headers
end

b = Celerity::Browser.new(:browser => :firefox)
#b = Celerity::Browser.new(:browser => :firefox, :log_level => :all)

if package == "spr"
    b.css = false
    b.javascript_enabled = false
end


if package == "ebr"
    b.css = false
    b.javascript_enabled = false
end

csv_data.each do |r|
  row_array = r.to_csv.parse_csv
  url = row_array.pop
  rest_of_data = row_array

  b.goto(url)
  page = b.html

  if package == "apb"
    sleeptime = 1
    if page.match(/type="onlineread"/)
      access = "Access probably ok"
    else
      access = "Check access manually"
    end  
      
  elsif package == "asp"
    sleeptime = 1   
    if page.include?("You do not have access to this page.")
      access = "No Access" 
    elsif page.include?("add-to-playlist")
        access = "Full access"
    else
      access = "Check access manually"
    end

  elsif package == "curio"
    sleeptime = 3
    if page.include?("Page not found")
        access = "Nope!"
    elsif page.include?("Access to platform content is limited")
      access = "Nope!"
    elsif  page.include?("schema.org/VideoObject")
      access = "Looking good!"
    else
      access = "Check access manually"
    end

  elsif package == "duphw"
    sleeptime = 1    
    if page.include?("DOI Not Found")
      access = "DOI error"
    else
      # I could find nothing on the ebook landing page to differentiate those to which we have full text access from those to which we do not.
      # This requires an extra step of having the checker visit one of the content pages, and testing whether one gets the content, or a log-in page
      url_title_segment = page.match(/http:\/\/reader\.dukeupress\.edu\/([^\/]*)\/\d+/).captures[0]
      content_url = "http://reader.dukeupress.edu/#{url_title_segment}/25"
  
      # Celerity couldn't handle opening the fulltext content pages that actually work,
      #  so I switch here to using open-uri to grab the HTML
  
      thepage = ""
      open(content_url) {|f|
        f.each_line {|line| thepage << line}
        }
      
      if thepage.include?("Log in to the e-Duke Books Scholarly Collection site")
        access = "No access"
      elsif thepage.include?("t-page-nav-arrows")
        access = "Full access"
      else
        access = "Check access manually"
      end
    end
  
  
  elsif package == "ebr"
    sleeptime = 2
    if page.include?("Your institution has unlimited access to this book")
      access = "Full access"
    elsif page.include?("Not Available for Online Reading")
        access = "No access"
    else
      access = "Check access manually"
    end

  elsif package == "ebs"
    sleeptime = 1
    if page.match("std-warning-text")
      access = "No access"
    elsif page.include?("record-type pdf-ft" || "record-type epub")
        access = "Full access"
    else
      access = "check"
    end

  elsif package == "end"
    sleeptime = 1
    if page.include?("Invalid record")
      access = "deleted OK"
    else
      access = "possible ghost record - check"
    end    

  elsif package == "fmgfod"
    sleeptime = 5
    if page.include?("The title you are looking for is no longer available")
      access = "No access"
    elsif page.match(/class="now-playing-div/)
      access = "Full access"
    else
      access = "Check access manually"
    end

    elsif package == "jstor"
    sleeptime = 5
    if page.include?("Your institution has not purchased this book from JSTOR")
      access = "Nope!"
    elsif page.include?("Download Chapter")
      access = "Right On!"
    else
      access = "Check access manually"
    end

      elsif package == "muse"
    sleeptime = 3
    if page.include?("access_no")
      access = "Nope!"
    elsif page.include?("access_yes")
      access = "Right On!"
    else
      access = "Check access manually"
    end
    
  elsif package == "nccorv"
    sleeptime = 1
    if page.match(/<div id="relatedVolumes">/)
      access = "related volumes section present"
    else
      access = "no related volumes section"
    end

  elsif package == "sabov"
    sleeptime = 1
    if page.match(/<a name="otherVols">/)
      access = "other volumes section present"
    else
      access = "no other volumes section"
    end
      
  elsif package == "scid"
    sleeptime = 1
    if page.match(/<td class=nonSerialEntitlementIcon><span class="sprite_nsubIcon_sci_dir"/)
      access = "Restricted access"
    elsif page.match(/title="You are entitled to access the full text of this document"/)
      access = "Full access"
    else
      access = "check"
    end    

  elsif package == "skno"
    sleeptime = 1
    if page.include?("Page Not Found")
      access = "No access - page not found"
    elsif page.include?("Users without subscription are not able to see the full content")
      access = "Restricted access"
    elsif page.match(/class="restrictedContent"/)
      access = "Restricted access"
    elsif page.match(/<p class="lockicon">/)
      access = "Restricted access"
    else
      access = "Probable full access"
    end

  elsif package == "spr"
    sleeptime = 1
    if page.match("access-link") != nil 
      access = "Restricted access"
    elsif page.match("Download Book") != nil
      access = "Full access"
    elsif page.match("DOI Not Found") != nil
      access = "DOI error"
    elsif page.include?("Bookshop, Wageningen")
      access = "wageningenacademic.com"
    else
      access = "Check access manually"
  end
    
  elsif package == "srmo"
    sleeptime = 1
    if page.include?("Page Not Found")
      access = "No access - page not found"
      elsif page.include?("Add to Methods List")
        access = "Probable full access"
    else
      access = "Check access manually"
    end

  elsif package == "ss"
    sleeptime = 1
    if page.include? "SS_NoJournalFoundMsg"
      access = "No access indicated"
    elsif page.include? "SS_Holding"
      access = "Access indicated"
    else
      access = "Check access manually"
    end

  elsif package == "upso"
    sleeptime = 1
    if page.include?("<div class=\"contentRestrictedMessage\">")
      access = "Restricted access"
    elsif page.include?("<div class=\"contentItem\">")
      access = "Full access"
    elsif page.include? "DOI Not Found"
      access = "DOI Error"
    else
      access = "Check access manually"
    end

  elsif package == 'wol'
    sleeptime = 1
    if page.include?("You have full text access to this content")
      access = "Full access"
    elsif page.include?("You have free access to this content")
      access = "Full access (free)"
    elsif page.include?("DOI Not Found")
      access = "DOI error"
    else
      access = "Check access manually"
    end
  end

  CSV.open(output, "a") do |c|
    c << [rest_of_data, url, access].flatten
  end

  counter += 1
  puts "#{counter} of #{total}, access = #{access}"
  
  sleep sleeptime
end
  finish = Time.now #end of run time counter for benchmarking
  diff = finish - start  
  puts diff
