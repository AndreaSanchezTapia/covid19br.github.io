library(ggplot2)
library(dplyr)
library(tidyr)
library(zoo)
library(EpiEstim) 
library(readr)
library(knitr)
library(cowplot)

################################################################################
## Parametros de formatacao comum aos plots
################################################################################
plot.formatos <- theme_bw()+
  theme(axis.text= element_text(size=10, face="bold"),
        axis.title = element_text(size=10, face="bold"),
        legend.text = element_text(size=12),
        title = element_text(size = 12),
        plot.margin = margin(5, 0, 0, 0, "pt"))
  

################################################################################
## Grafico da serie observada e do previsto pelo modelo exponencial
## para os proximos 5 dias (com intervalo de confiança)
################################################################################
## Serie com observados e previstos
## (gambiarra para ter linha contínua no grafico, verificar help de ggplot.zoo)
ncasos.completa <-merge(casos=brasil$casos.acumulados, exp.5d[, c("predito","ic.low","ic.upp")])
ncasos.completa$casos[time(ncasos.completa)>=min(time(exp.5d))] <- exp.5d$predito[time(exp.5d)>=min(time(exp.5d))]

plot.forecast.exp.br <-
    ggplot(data=ncasos.completa, aes(x=Index, y=casos,ymin=ic.low, ymax=ic.upp)) +
    geom_ribbon(fill="lightgrey") +
    geom_line() +
    geom_point(data=ncasos.completa[time(ncasos.completa)<=min(time(exp.5d))], size=2,
               aes(text = paste("Data:", Index, "\n",
                                "Casos:", round(casos)))) +
    geom_point(data=ncasos.completa[time(ncasos.completa)>=min(time(exp.5d))],
               aes(text = paste("Data:", Index, "\n",
                        "Casos previstos:", round(casos), "\n",
                        "IC min:", round(ic.low), "\n",
                        "IC max:", round(ic.upp))),
                size=2, col="#007bff") +
    scale_x_date(date_labels = "%d/%b", name="", limits=c(as.Date('2020-02-25'), NA)) +
    scale_y_log10() +
    ##ylim(0,max(ncasos.completa$ic.upp, na.rm=TRUE)) +
    ylab("Número de casos") +
    ggtitle("Número de casos notificados em escala logarítimica") +
    plot.formatos

################################################################################
##Tempo de duplicacao calculado para uma janela de 5 dias, a partir do dia zero
################################################################################
plot.tempo.dupl <-
    ggplot(tempos.duplicacao, aes(Index, estimativa)) +
    geom_ribbon(aes(ymin = ic.inf, ymax = ic.sup), fill="lightgrey") +
    geom_line(size = 1.25, color="darkblue") +
    scale_x_date(#breaks=seq(min(time(ncasos.completa)), max(time(ncasos.completa)), by=3),
                date_labels = "%d/%b", name="") +
    ylab("Tempo de duplicação (dias)") +
    plot.formatos 

# Default config will estimate R on weekly sliding windows.
## plot.estimate.R <- plot(res.uncertain.si, "R", legend=TRUE) + plot.formatos
plot.estimate.R0 <-
    ggplot(data = res.uncertain.si.zoo, aes(Index, Mean.R)) +
    geom_ribbon(aes(ymin = Quantile.0.025.R, ymax = Quantile.0.975.R), fill="lightgrey") +
    geom_line(size = 1.25, color="darkblue") +
    scale_x_date( date_labels = "%d/%b", name="") +
    ylim(0.8, max(res.uncertain.si.zoo$Quantile.0.975.R))+
    geom_hline(yintercept=1, linetype="dashed", col="red") +          
    ylab("Número de reprodução") +
    plot.formatos

################################################################################
## Série temporal dos tempos de duplicação
################################################################################
ex.dt <- dt.rw(brasil.d0[1:10], window.width =5)
ex.dt$coef  <-  round(ex.dt$coef,1)
ex.dt$coef.low  <- round(ex.dt$coef.low,1)
ex.dt$coef.upp  <- round(ex.dt$coef.upp,1)
ex.dt.df <- as.data.frame(ex.dt[,c(1,3,2)])
rownames(ex.dt.df) <- format(as.Date(rownames(ex.dt.df)), "%d/%m/%Y")
serie.temp.table <- kable(ex.dt.df, "html", col.names=c("Estimado", "IC-inferior", "IC-superior"),
                          caption="Estimativas dos tempos de duplicação do número de casos de COVID-19 para o Brasil, para período de 5 dias, a partir de 07 de março de 2020. Indicados os valores estimados e os limites inferiores e superiores do intervalo de confiança a 95%. As datas em cada linha da tabela são os dias do final de cada período.",
                          pagetitle = "09")

################################################################################
## Estimativa tempo de duplicação
################################################################################

exemplo1 <- window(brasil, start="2020-03-07",end="2020-03-11")
ex.fit <- fitP.exp(exemplo1$casos.acumulados, only.coef=FALSE)
exemplo1$pred <- predict(ex.fit, type="response")
est.tempo.dupl <- ggplot(exemplo1,
                         aes(Index, casos.acumulados)) +
  geom_point(size=2, color="darkblue") +
  geom_line(aes(Index, pred)) +
  scale_x_date(date_labels = "%d/%b", name="") +
  ylab("log (Número de casos)") +
  scale_y_log10() +
  plot.formatos

################################################################################
## Projeções de número de casos 
################################################################################
ex.forecast <- forecast.exponential(exemplo1$casos.acumulados,
                                    start=as.Date("2020-03-07"),
                                    days.forecast = 5)
exemplo2 <- window(brasil, start="2020-03-07", end="2020-03-16")
exemplo2 <- merge(exemplo2,
                  zoo(data.frame(pred=predict(ex.fit, newdata=data.frame(ndias=0:10), type="response")),
                      time(exemplo2)))              
proj.num.casos <- ggplot(data= exemplo2, aes(Index, casos.acumulados)) +
  geom_point(size=2, color="darkblue") +
  geom_line(aes(Index, pred)) +
  geom_ribbon(data=ex.forecast, aes(y=predito, ymin=ic.low, ymax=ic.upp), alpha=0.2) +
  scale_x_date(date_labels = "%d/%b", name="") +
  ylab("log (Número de casos)") +
  scale_y_log10() +
  plot.formatos

######################################################################
## Tabela para preencher o minimo e o máximo
######################################################################
# Create a dataframe with all the locations as row names. Add VR
minmax.casos <- data.frame(row.names = c("BR"))
# Get all the places in a dataframe
minmax.lugares <- exp.5d

min <- as.integer(minmax.lugares[max(nrow(minmax.lugares)),2])
max <- as.integer(minmax.lugares[max(nrow(minmax.lugares)),3])
data <- format(max(time(minmax.lugares)), "%d/%m/%Y")

# Fill the table
minmax.casos <- cbind(minmax.casos, min, max, data)
# Order table by max cases
minmax.casos <- minmax.casos[order(-max),] 
# Save to a csv
write.table(minmax.casos, file="../web/data_forecast_exp_br.csv", row.names = TRUE, col.names = FALSE)

