library(RDSTK)
library(foreach)
library(ggmap)

#CSV data should include addresses in single column
# with street, city, state, and zip separated by commas

address.data=read.csv(file.choose(),header=TRUE)


#Function uses Data Science Toolkit to geocode addresses, then restructure results.

new.street2coords <- function(str){

ad<-try(street2coordinates(str))

  if (ncol(ad) > 0) {
full.address<-ad$full.address
street.address<-ad$street_address
latitude<-ad$latitude
longitude<-ad$longitude
confidence<-ad$confidence

    }
    else {    
full.address<-street.address<-latitude<-longitude<-confidence<-NA    }
    cbind(full.address,street.address,latitude,longitude,confidence)
}  

#Run above function on each address, then combine into data frame

geocoded.addresses<-foreach(a=as.character(unique(address.data$full.addresses)), .combine=rbind) %do% try(new.street2coords(a))
geocoded.addresses<-as.data.frame(geocoded.addresses)

#Split geocoded addresses with high confidence all other addresses.

geocoded.addresses.above.85.confa<-geocoded.addresses[grep("Error",geocoded.addresses$confidence,invert=TRUE),]
geocoded.addresses.above.85.conf<-geocoded.addresses.above.85.confa[which(as.vector(geocoded.addresses.above.85.confa$confidence)>=.85),]
address.data.2 <- as.data.frame(merge(address.data, geocoded.addresses.above.85.conf, by.x = "full.addresses", by.y = "full.address",all.x=TRUE))

#Extract addresses to recode using Microsoft Search Engine Map API

address.data.to.recode<-address.data.2[which(is.na(address.data.2$confidence)==TRUE),]
address.data.geocoded.above.85<-address.data.2[which(is.na(address.data.2$confidence)==FALSE),]



#Recode using Microsoft Search Engine Map API

bGeoCode <- function(str, BingMapsKey){
    require(RCurl)
    require(RJSONIO)
    u <- URLencode(paste0("http://dev.virtualearth.net/REST/v1/Locations?q=", str, "&maxResults=1&key=", BingMapsKey))
    d <- getURL(u)
    j <- fromJSON(d) 
    if (j$resourceSets[[1]]$estimatedTotal > 0) {
formatted.address<-paste(j$resourceSets[[1]]$resources[[1]]$address,collapse=",")
entity.type<-j$resourceSets[[1]]$resources[[1]]$entityType

confidence<-j$resourceSets[[1]]$resources[[1]]$confidence[1]
      lat <- j$resourceSets[[1]]$resources[[1]]$point$coordinates[[1]]
      lng <- j$resourceSets[[1]]$resources[[1]]$point$coordinates[[2]]
    }
    else {    
formatted.address<-"Unmatched"
entity.type<-"Unmatched"
confidence<- "Unmatched"
lat <- "Unmatched"
lng <- "Unmatched"
cbind(str,formatted.address,entity.type,confidence,lat,lng)
    }
    cbind(str,formatted.address,entity.type,confidence,lat,lng)
}  

#Clean up text in addresses with missing geocodes before running above fxn

address.data.to.recode<-as.vector(address.data.to.recode$full.addresses)
 address.data.to.recode2<-gsub('&',' ',address.data.to.recode)
 address.data.to.recode2<-gsub('/','-',address.data.to.recode2)
 address.data.to.recode2<-gsub('#','',address.data.to.recode2)
address.data.to.recode3<-as.data.frame(address.data.to.recode2)
address.data.to.recode3$nmbr.of.chars<-nchar(address.data.to.recode2)
address.data.to.recode3$chars.less.than.20<-address.data.to.recode3$nmbr.of.chars>=20
address.data.to.recode4<-address.data.to.recode3[which(address.data.to.recode3$chars.less.than.20==TRUE),]
address.data.to.recode5<-as.character(address.data.to.recode4$address.data.to.recode2)

#Geocode missing data using Microsoft Search Engine API
#Sign up for your own bing maps key here:https://msdn.microsoft.com/en-us/library/ff428642.aspx

missing.geocoded.addresses<-foreach(a=address.data.to.recode5, .combine=rbind) %do% try(bGeoCode(a,"insert_your_bing_maps_key_here"))
colnames(missing.geocoded.addresses)<-c("full.addresses","street.address","entity.type","confidence" ,"latitude","longitude")


#Clean up final data geocode data before combining and exporting to CSV

address.data.geocoded.above.85$entity.type<-"85 pct confidence or higher"
address.data.geocoded.above.85.2<-address.data.geocoded.above.85[,c("full.addresses","street.address","entity.type","confidence","latitude","longitude")]


missing.geocoded.addresses2<-as.data.frame(missing.geocoded.addresses)
address.data.geocoded.above.85.2$keep<-1
missing.geocoded.addresses2$keep<-0

missing.geocoded.addresses2$keep <- as.character(missing.geocoded.addresses2$keep)
missing.geocoded.addresses2$keep[missing.geocoded.addresses2$entity.type == "Address" & missing.geocoded.addresses2$confidence=="High"] <- "1"
missing.geocoded.addresses2$keep<- as.character(missing.geocoded.addresses2$keep)


#Combine final geocodes before exporting.

final.geocodes<-rbind(address.data.geocoded.above.85.2,missing.geocoded.addresses2)

#Percent of addresses that were coded correctly = 1
prop.table(table(final.geocodes$keep))


write.csv(final.geocodes, file = paste("geocoded.addresses",gsub("-|:","_",Sys.time()),".csv",sep=""),row.names=FALSE)



#LASTLY...
#Run below code to visualize EXAMPLE addresses 
#as points on map in Los Angeles

LAMap<-qmap("Los Angeles",zoom=10)  #First, get a map of Los Angeles
longitude<-as.numeric(as.vector(final.geocodes$longitude))
latitude<-as.numeric(as.vector(final.geocodes$latitude))
map.data<-as.data.frame(cbind(longitude,latitude))
LAMap+                                        ##This plots the L.A. Map
geom_point(aes(x = longitude, y = latitude), data = map.data)



