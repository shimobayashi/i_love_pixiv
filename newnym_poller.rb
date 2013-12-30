while true
  `(echo authenticate '""'; echo signal newnym; echo quit) | nc localhost 9051`
  sleep 10
end
