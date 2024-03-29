# Discovering Associations between Products

# Load packages ####
library(arules)
library(arulesViz)
library(RColorBrewer)
library(readxl)
library(cba)
library(shiny)
library(devtools)

# Read the dataset ####
transactions <- read.transactions('data/ElectronidexTransactions2017.csv', format='basket', sep=',', rm.duplicates = FALSE)
# The data is only 1 month of data. It would be more acurate to have a larger time period

# Remove empty rows from the transactions ####
transactions[-(which(size(transactions)==0))]

# Inspect the dataset ####
inspect(transactions)
length(transactions)
size(transactions)
LIST(transactions)
itemLabels(transactions)

# Visualize the dataset ####
image(transactions)
image(sample(transactions, 100))

itemFrequencyPlot(transactions, topN=nrow(itemInfo(transactions)), type='absolute',col=brewer.pal(8,'Pastel2'), main="Absolute Item Frequency Plot", ylab='Item Frequency (absolute)', cex=0.1, names=FALSE, xlab='Items')
itemFrequencyPlot(transactions, topN=25, type='absolute',col=brewer.pal(8,'Pastel2'), main="Absolute Item Frequency Plot", ylab='Item Frequency (absolute)', cex=1)
itemFrequencyPlot(transactions, topN=25, type='relative',col=brewer.pal(8,'Pastel2'), main="Relative Item Frequency Plot", ylab='Item Frequency (relative)', cex=1)

# Apply the apriori algorithm to find product rules ####
rules <- apriori(transactions, parameter = list(support = 0.01, confidence = 0.4, minlen=2))

# Inspect the rules ####
inspect(rules)
inspect(head(rules))
inspectDT(rules)

# Evaluate the rules ####
summary(rules)

# Visualize the rules ####
# plot(rules)
# plot(rules, method="graph", control=list(type="items"))
# plot(rules, method="paracoord", control=list(reorder=TRUE))

# Improve the model ####
rules_by_lift <- sort(rules, by = "lift")
inspect(rules_by_lift)
ItemRules <- subset(rules_by_lift, items %in% c("Apple Earpods","HP Laptop"))
inspect(ItemRules)
is.redundant(ItemRules)

# Read the products dataset (contains two products, one being the product names, the other being the product types) ####
products <- read_excel('data/products.xlsx',col_names = TRUE)
products <- as.data.frame(products)

# Create a categories vector that stores the product type of each product in the transactions ####
#categories_vector <- c()
# for (i in 1:length(transactions@itemInfo$labels)){
#   for (j in 1:nrow(products)){
#     if (transactions@itemInfo$labels[i] == products[[j,1]]){
#       categories_vector <- c(categories_vector,products[j,2])
#       break
#     }
#   }
# }
# Function that calculates the closest match to a string from a string vector
ClosestMatch <- function(string,StringVector) {
  matches <- agrep(string,StringVector,value=TRUE)
  if (length(matches) == 0){
    # Use the double assign to use the not_found_names as a global variable
    not_found_names <<- c(not_found_names,string)
  }
  distance <- sdists(string,matches,method = "ow")
  matches <- data.frame(matches,as.numeric(distance))
  matches <- subset(matches,distance==min(distance))
  as.character(matches$matches)
}
categories_vector <- c()
index_vector <- c()
not_found_names <- c()
# Loop to create the categories vector
for (i in 1:length(transactions@itemInfo$labels)){
  value <- ClosestMatch(transactions@itemInfo$labels[i], products$product)
  index <- which(products$product == value)
  index_vector <- c(index_vector,index)
  categories_vector <- c(categories_vector,products[index,2])
}
# Print the product names that have not found a match
not_found_names

# Change the product types that contain the wors "Gaming", "Game" or "Gamer" in their product name to a new category called "Gaming"
# gaming_indexes <- grepl("Gaming",transactions@itemInfo$labels)
# game_indexes <- grepl("Game",transactions@itemInfo$labels)
# gamer_indexes <- grepl("Gamer",transactions@itemInfo$labels)
# categories_vector[gaming_indexes] <- "Gaming"
# categories_vector[game_indexes] <- "Gaming"
# categories_vector[gamer_indexes] <- "Gaming"

# Group 'Laptops' and 'Desktop' under one category named 'PC' ####
#categories_vector[categories_vector == 'Laptops' | categories_vector == 'Desktop'] <- 'PC'

# Map the categories of electronidex to the categories of blackwell ####
# Get the categories of the blackwell data
existing_products <- read_excel('data/existingProductAttributes.xlsx', col_names = TRUE)
existing_products <- as.data.frame(existing_products)
# We have now 2 vectors containing the categories of each company
# existing_product_types --> categories of blackwell data
existing_product_types_blackwell <- unique(existing_products$ProductType)
existing_product_types_blackwell
# categories_vector --> categories of electronidex data
existing_product_types_electronidex <- unique(categories_vector)
existing_product_types_electronidex
# Organize the categories of blackwell based on the categories of electronidex
categories_vector_mapped <- c()

# Aggregate by categories ####
transactions_categories <- aggregate(transactions,categories_vector)

# Visualize the transactions by categories ####
itemFrequencyPlot(transactions_categories, topN=nrow(itemInfo(transactions_categories)), type='absolute',col=brewer.pal(8,'Pastel2'), main="Category Frequency Plot", ylab='Category Frequency (absolute)', cex=1, xlab='Categories')

# Inspect rules by categories ####
rules_categories <- apriori(transactions_categories, parameter = list(support = 0.1, confidence = 0.1, minlen=2))
rules_categories_by_confidence <- sort(rules_categories, by = "lift")
inspect(rules_categories_by_confidence)

# Visualize the rules ####
#tr_cat_df <- as(transactions_categories,'matrix')
#source_gist(id='706a28f832a33e90283b')
#arulesApp(transactions_categories)

# Convert the sparse matrix of transactions into a dataframe ####
transactions_dataframe <- as.data.frame(t(as.matrix((transactions@data))))
colnames(transactions_dataframe)<-transactions@itemInfo$labels
transactions_categories_dataframe <- as.data.frame(t(as.matrix((transactions_categories@data))))
colnames(transactions_categories_dataframe)<-transactions_categories@itemInfo$labels
# Create another variable to alter, while still keeping the original for later
transactions_df <- transactions_dataframe
#transactions_df_int = as.data.frame(sapply(transactions_df, as.integer))

# Separate customers from distributors ####
# Create a list that contains as many vectors as product types, and every product type vector is filled with all the product names of that product type. columns for each category in the transactions dataframe and initialize a list of product types that will later be filled
product_types_list <- list()
# Fill the list of product types with all product names of each product type (watch out: the index_vector that links the product names to product types is used here)
for (i in 1:length(transactions@itemInfo$labels)){
  product_types_list[[products[index_vector[i],2]]] <- c(product_types_list[[products[index_vector[i],2]]],transactions@itemInfo$labels[i])
}
# Fill the columns of the product types with the number of product types bought per transaction
for (category in unique(categories_vector)){
  transactions_df[,category] <- rowSums(transactions_df[product_types_list[[category]]])
}
# Calculate who is a customer and who is a distributor based on whether they bought two items of the same category or not and save the indices to two different vectors
distributors_indices <- which(rowSums(transactions_df[,unique(categories_vector)] > 1) > 0)
# Add transactions with more than one of the 'PC' types to distributors
desktop_1 <- intersect(which(transactions_df$Desktop==1),which(transactions_df$Laptops==1))
desktop_2 <- intersect(which(transactions_df$Laptops==1),which(transactions_df$`Gaming Pc` == 1))
desktop_3 <- intersect(which(transactions_df$`Gaming Pc` == 1), which(transactions_df$Desktop==1))
desktops_indices <- union(union(desktop_1,desktop_2),desktop_3)
distributors_indices <- union(distributors_indices,desktops_indices)

# Create the transactions containing only customers rows and only distributors rows, separated by product names and by product types
transactions_customers_items_df <- transactions_dataframe[-distributors_indices,]
transactions_distributors_items_df <- transactions_dataframe[distributors_indices,]
transactions_customers_categories_df <- transactions_categories_dataframe[-distributors_indices,]
transactions_distributors_categories_df <- transactions_categories_dataframe[distributors_indices,]
# Create transactions tables from the dataframes ####
transactions_customers_items <- as(transactions_customers_items_df,'transactions')
transactions_distributors_items <- as(transactions_distributors_items_df,'transactions')
transactions_customers_categories <- as(transactions_customers_categories_df,'transactions')
transactions_distributors_categories <- as(transactions_distributors_categories_df,'transactions')

# Calculate the rules for each of the 4 transactions tables using the apriori algorithm, sort by confidence, and inspect the rules ####
rules_customers_categories <- apriori(transactions_customers_categories, parameter = list(support = 0.05, confidence = 0.1, minlen=2))
rules_customers_categories_by_conf <- sort(rules_customers_categories, by = "confidence")
inspect(rules_customers_categories_by_conf)
rules_distributors_categories <- apriori(transactions_distributors_categories, parameter = list(support = 0.05, confidence = 0.85, minlen=2))
rules_distributors_categories_by_conf <- sort(rules_distributors_categories, by = "confidence")
inspect(rules_distributors_categories_by_conf)

# Create vectors for the top categories, the top apple products, and the gaming computers to later investigate their rules ####
top_categories <- c('Desktop','Laptops')
apple_top_products <- c('iMac','Apple Earpods','Apple MacBook Air')
gaming_computers <- c('Gaming Pc')

# Put the Laptops and Desktops on the lhs for the customers_catgories transactions ####
rules_customers_categories <- apriori(transactions_customers_categories, parameter = list(support = 0.005, confidence = 0.1, minlen=2), appearance = list(lhs = top_categories))
rules_customers_categories_by_conf <- sort(rules_customers_categories, by = "lift")
rules_customers_categories_by_conf <- rules_customers_categories_by_conf[!is.redundant(rules_customers_categories_by_conf)]
inspect(rules_customers_categories_by_conf)
plot(rules_customers_categories_by_conf, method="graph", control=list(type="items"))

# Put the Laptops and Desktops on the lhs for the distributors_categories transactions ####
rules_distributors_categories <- apriori(transactions_distributors_categories, parameter = list(support = 0.01, confidence = 0.2, minlen=2), appearance = list(lhs = top_categories))
rules_distributors_categories_by_conf <- sort(rules_distributors_categories, by = "lift")
rules_distributors_categories_by_conf <- rules_distributors_categories_by_conf[!is.redundant(rules_distributors_categories_by_conf)]
inspect(rules_distributors_categories_by_conf)
plot(rules_distributors_categories_by_conf, method="graph", control=list(type="items"))

# Put the iMac on the lhs for the customers_categories transactions ####
rules_customers_items <- apriori(transactions_customers_items, parameter = list(support = 0.0001, confidence = 0.025, minlen=2), appearance = list(lhs = 'iMac'))
rules_customers_items_by_conf <- sort(rules_customers_items, by = "lift")
rules_customers_items_by_conf <- rules_customers_items_by_conf[!is.redundant(rules_customers_items_by_conf)]
inspect(rules_customers_items_by_conf)
plot(rules_customers_items_by_conf, method="graph", control=list(type="items"))

# Put the iMac on the lhs for the distributors_categories transactions ####
rules_distributors_items <- apriori(transactions_distributors_items, parameter = list(support = 0.01, confidence = 0.1, minlen=2), appearance = list(lhs = 'iMac'))
rules_distributors_items_by_conf <- sort(rules_distributors_items, by = "lift")
rules_distributors_items_by_conf <- rules_distributors_items_by_conf[!is.redundant(rules_distributors_items_by_conf)]
inspect(rules_distributors_items_by_conf)
plot(rules_distributors_items_by_conf, method="graph", control=list(type="items"))

# Plot the proportion of Retailers buying multiple Gaming Pcs (which will be considered Gaming retailers) ####
retailers_buying_one_gaming_pc <- sum(transactions_df['Gaming Pc'] > 0) - sum(transactions_customers_categories_df['Gaming Pc'] > 0) - sum(transactions_df['Gaming Pc'] > 1)
retailers_buying_multiple_gaming_pc <- sum(transactions_df['Gaming Pc'] > 1)
multiple_gaming_pcs <- data.frame (type = c("One Gaming PC", "Multiple Gaming PCs"), number = c(retailers_buying_one_gaming_pc,retailers_buying_multiple_gaming_pc), prop = c(retailers_buying_one_gaming_pc/(retailers_buying_one_gaming_pc+retailers_buying_multiple_gaming_pc), retailers_buying_multiple_gaming_pc/(retailers_buying_multiple_gaming_pc + retailers_buying_one_gaming_pc)) )
ggplot( data = multiple_gaming_pcs, aes( x= "", y = number,  fill = type))+
  geom_bar(stat = "identity", color = "white")+
  coord_polar("y", start=0)+
  scale_fill_brewer(palette="Blues")+
  theme_void()+
  geom_text(aes(label = paste0(round(number),  " - ", round(prop*100), "%")), position = position_stack(vjust = 0.5)) +
  ggtitle('Proportion of Retailers buying multiple Gaming PCs')

# Plot the proportion of Retailers buying Gamingg Pcs ####
retailers_buying_gaming_pc <- sum(transactions_distributors_categories_df['Gaming Pc'] > 0)
retailers_not_buying_gaming_pc <- 4822 - sum(transactions_distributors_categories_df['Gaming Pc'] > 0)
buying_gaming_pcs <- data.frame (type = c("Buying Gaming PCs", "Not Buying Gaming PCs"), number = c(retailers_buying_gaming_pc,retailers_not_buying_gaming_pc), prop = c(retailers_buying_gaming_pc/(retailers_buying_gaming_pc+retailers_not_buying_gaming_pc), retailers_not_buying_gaming_pc/(retailers_buying_gaming_pc + retailers_not_buying_gaming_pc)) )
ggplot( data = buying_gaming_pcs, aes( x= "", y = number,  fill = type))+
  geom_bar(stat = "identity", color = "white")+
  coord_polar("y", start=0)+
  scale_fill_brewer(palette="Blues")+
  theme_void()+
  geom_text(aes(label = paste0(round(number),  " - ", round(prop*100), "%")), position = position_stack(vjust = 0.5)) +
  ggtitle('Proportion of Retailers buying Gaming PCs')

# Plot the percentage of items bought in Distributors transactions vs in Customers transactions ####
items_customers <- sum(size(transactions_customers_items))
items_distributors <- sum(size(transactions_distributors_items))
items_transaction_distribution <- data.frame (type = c("Customer number of items", "Distributors number of items"), number = c(items_customers,items_distributors), prop = c(items_customers/(items_customers+items_distributors), items_distributors/(items_customers + items_distributors)) )
ggplot( data = items_transaction_distribution, aes( x= "", y = number,  fill = type))+
  geom_bar(stat = "identity", color = "white")+
  coord_polar("y", start=0)+
  scale_fill_brewer(palette="Blues")+
  theme_void()+
  geom_text(aes(label = paste0(round(number),  " - ", round(prop*100), "%")), position = position_stack(vjust = 0.5)) +
  ggtitle('Proportion of Retailers buying Gaming PCs')
