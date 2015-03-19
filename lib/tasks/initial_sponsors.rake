
namespace :initial_sponsors do

  desc 'Add initial sponsors to DB'
  task :add_initial_sponsors => :environment do
    InstitutionalSponsor.create(name: "Atlas of Living Australia", logo_url: "https://github.com/EOL/eol/blob/master/app/assets/images/map.png", url: "http://www.ala.org.au/", active: true)
    InstitutionalSponsor.create(name: "Bibliotheca Alexandrina", logo_url: "https://github.com/EOL/eol/blob/master/app/assets/images/map.png", url: "http://www.bibalex.org/", active: true)
    InstitutionalSponsor.create(name: "Chinese Academy of Sciences", logo_url: "https://github.com/EOL/eol/blob/master/app/assets/images/map.png", url: "http://english.cas.cn/", active: true)
    InstitutionalSponsor.create(name: "CONABIO", logo_url: "https://github.com/EOL/eol/blob/master/app/assets/images/map.png", url: "http://www.conabio.gob.mx/", active: true)
    InstitutionalSponsor.create(name: "Harvard University", logo_url: "https://github.com/EOL/eol/blob/master/app/assets/images/map.png", url: "http://www.harvard.edu/", active: true)
    InstitutionalSponsor.create(name: "Marine Biological Laboratory", logo_url: "https://github.com/EOL/eol/blob/master/app/assets/images/map.png", url: "http://www.mbl.edu/", active: true)
    InstitutionalSponsor.create(name: "Smithsonian Institution", logo_url: "https://github.com/EOL/eol/blob/master/app/assets/images/map.png", url: "http://www.si.edu/", active: true)
  end
end