#
# Setup
## Loading the cleaned UDS sample:

# Sample UDS Dataset
udf <- read.csv('https://drive.google.com/uc?export=download&id=1QWKkvQXS09l8_qH1IAnMIpJ-TwZGw4hk')
# Sample MRI Dataset
mdf <- read.csv('https://drive.google.com/uc?export=download&id=1am_Iu0zhKiF4ShN4Rw6b_uXn8Obv_BnG')

# Tidyverse
suppressPackageStartupMessages(library(tidyverse))

# GGally for pairs-plot
if(!require(GGally)){
  install.packages("GGally")
  library(GGally)
}

# glmnet for Lasso
if(!require(glmnet)){
  install.packages("glmnet")
  library(glmnet)
}

# Join
jdf <- udf |> left_join(mdf, by = 'ID')

# Conditions
m01xs <- c('ANX', # Anxiety: No/Yes
           #'CONGHRT', # Congestive Heart Failure: No/Yes Limiting observations
           'DEP2YRS', # Depression last 2 years: No/Yes
           'BEAHALL', # Auditory Hallucination: No/Yes
           'HYPERTEN', # Hypertension Status: None, Inactive, Active
           'DIABTYPE' # Diabetes Type: None, I, II, III
)
# Demographics
m02xs <- c('SEX',
           'NACCAGE', # Age
           'MARISTAT', # Marital Status
           #'DECAGE', # Decline Age (only relevant to AlzD and limiting data)
           'EDUC', # Years of Education
           'NACCNIHR' # Race
)

# Measurements
m03xs <- c('BPDIAS', # Diastolic Blood Pressure
           'BPSYS', # Systolic Blood Pressure
           'HRATE' # Heart Rate
           #,'MINTTOTS' # Multilingual Naming Test: Total Score Limiting obs
)

m04xs <- c('LHIPPO', 'RHIPPO', 'HIPPOVOL', 'CSFVOL', 'GRAYVOL', 'WHITEVOL',
           'LFRCORT', 'RFRCORT', 'FRCORT')

jdf |> select(all_of(m01xs)) |>
  summarise(across(everything(), function(x) sum(is.na(x))))

jdf |> select(all_of(m02xs)) |>
  summarise(across(everything(), function(x) sum(is.na(x))))

jdf |> select(all_of(m03xs)) |>
  summarise(across(everything(), function(x) sum(is.na(x))))

jdf |> select(all_of(m04xs)) |>
  summarise(across(everything(), function(x) sum(is.na(x))))

jdf |> select(all_of(c(m01xs, m02xs, m03xs, m04xs))) |> (function(x) sum(complete.cases(x)))()


jdf <- udf |> left_join(mdf, by = 'ID') |>
  select('NACCALZD',
         'DECAGE',
         'MINTTOTS',
         'ANX', # Anxiety: No/Yes
         'DEP2YRS', # Depression last 2 years: No/Yes
         'BEAHALL', # Auditory Hallucination: No/Yes
         'HYPERTEN', # Hypertension Status: None, Inactive, Active
         'DIABTYPE' # Diabetes Type: None, I, II, III
         ,'SEX',
         'NACCAGE', # Age
         'MARISTAT', # Marital Status
         'EDUC', # Years of Education
         'NACCNIHR' # Race
         ,'BPDIAS', # Diastolic Blood Pressure
         'BPSYS', # Systolic Blood Pressure
         'HRATE' # Heart Rate
         ,'LHIPPO', 'RHIPPO', 'HIPPOVOL', 'CSFVOL', 'GRAYVOL', 'WHITEVOL',
         'LFRCORT', 'RFRCORT', 'FRCORT'
  )

#
jdf <- jdf |>
  mutate(AlzD = factor(NACCALZD, c('Dementia', 'Normal', 'Alzheimer'),
                       c('No', 'No', 'Yes')),
         ANX = factor(ANX, c("No", "Yes")),
         DEP2YRS = factor(DEP2YRS, c("No", "Yes")),
         BEAHALL = factor(BEAHALL, c("No", "Yes")),
         HYPERTEN = factor(HYPERTEN,
                           c('Absent','Remote/Inactive','Recent/Active'),
                           c('None', 'Inactive', 'Active')),
         DIABTYPE = factor(DIABTYPE,
                           c('None', 'Type I', 'Type II', 'Other Types'),
                           c('None', 'Type1', 'Type2', 'OtherType')),
         SEX = factor(SEX, c('Male', 'Female')),
         MARISTAT = factor(MARISTAT,
                           c('Never Married', 'Married' , 'As.Married',
                             'Widowed', 'Divorced', 'Separated'),
                           c('Single', 'Couple', 'Couple',
                             'Alone', 'Alone', 'Alone'))
  )

# Lm ####
mdl01 <- lm(DECAGE ~ SEX + EDUC + BPDIAS + BPSYS + HRATE + MARISTAT +
              DEP2YRS + HYPERTEN + DIABTYPE, jdf)

summary(mdl01)

par(mfrow=c(2,2), mar=c(2,2,2,2),
    mgp=c(1,0,0))
plot(mdl01, cex=1)

# Pairs
pairs(DECAGE ~ SEX + EDUC + BPDIAS + BPSYS + HRATE + MARISTAT +
        DEP2YRS + HYPERTEN + DIABTYPE, jdf)


jdf %>% select(DECAGE, EDUC, BPDIAS, BPSYS, HRATE) %>% drop_na() %>%
  ggpairs()


jdf %>% select(DECAGE, EDUC, BPDIAS, BPSYS, HRATE, AlzD) %>% drop_na() %>%
  ggpairs(aes(color=AlzD))


# Glm ####
mdl02 <- glm(AlzD ~ LHIPPO+RHIPPO+HIPPOVOL+CSFVOL+
               GRAYVOL+WHITEVOL+LFRCORT+RFRCORT+FRCORT,
             data = jdf, family = binomial())
summary(mdl02)

# CSFVOL and WHITEVOL are significant
jdf %>% ggplot(aes(x=WHITEVOL, y=CSFVOL, color = AlzD))+
  geom_point()

jdf %>% select(LHIPPO, RHIPPO, HIPPOVOL, CSFVOL,
               GRAYVOL, WHITEVOL, LFRCORT, RFRCORT, FRCORT) %>% drop_na() %>% ggpairs()

jdf %>% select(LHIPPO, RHIPPO, HIPPOVOL, CSFVOL,
               GRAYVOL, WHITEVOL, LFRCORT, RFRCORT, FRCORT, AlzD) %>% drop_na() %>%
  ggpairs(aes(color=AlzD))




# CSFVOL and WHITEVOL are significant
jdf %>% ggplot(aes(x=WHITEVOL, y=CSFVOL, color = AlzD))+
  geom_point()

xvdf <- jdf %>% select(AlzD, LHIPPO, RHIPPO, HIPPOVOL, CSFVOL,
                         GRAYVOL, WHITEVOL, LFRCORT, RFRCORT, FRCORT) %>%
  drop_na()
mmat <- model.matrix(object = AlzD~., data = xvdf)
x <- mmat[,-1]
y <- xvdf$AlzD

# Lasso
if(!require(glmnet)){
  install.packages("glmnet")
  library(glmnet)
}
lasso_model <- cv.glmnet(x, y, alpha = 1, family = 'binomial')
lasso_model

# Optimal lambda
optimal_lambda <- lasso_model$lambda.min
print(optimal_lambda)

plot(lasso_model)

# Coefficients at optimal lambda
lasso_coefficients <- coef(lasso_model, s = "lambda.min")
print(lasso_coefficients)

lasso_coefficients <- coef(lasso_model, s = "lambda.1se")
print(lasso_coefficients)

pairs(jdf[, c('AlzD', 'LHIPPO', 'HIPPOVOL', 'CSFVOL')])




