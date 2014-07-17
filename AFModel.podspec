Pod::Spec.new do |s|
  s.name				= "AFModel"
  s.version				= "0.1.0"
  s.summary				= "A model framework for iOS."
  s.description			= <<-DESC
						  A model framework for iOS.
						  DESC
  s.homepage			= "https://github.com/mlatham/AFModel"
  s.license				= "WTFPL"
  s.author				= { "Matt Latham" => "matt.e.latham@gmail.com" }
  s.social_media_url	= "https://twitter.com/mattlath"
  
  s.source				= { :git => "https://github.com/mlatham/AFModel.git", :tag => "v0.1.0" }
  s.source_files		= 'AFModel/Pod/**/*.{h,m}'
  s.public_header_files = 'AFModel/Pod/**/*.h'

  s.prefix_header_contents = '#import "AFModel-Includes.h"'

  s.platform			= :ios, "6.0"
  s.requires_arc		= true

end
