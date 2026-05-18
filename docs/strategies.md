# Strategies

## MA Cross (`ma-cross`)

Uses 9- and 21-period simple moving averages on 15-minute closes. Entries require RSI confirmation (long when RSI < 65, short when RSI > 35). Exits flatten when the fast MA crosses back through the slow MA.

## Grid (`grid`)

Builds five spaced price bands around the last trade. Opens a long when price dips to the nearest lower band; closes when price reaches the nearest upper band. Best suited to ranging markets—trending markets may stack risk quickly.
