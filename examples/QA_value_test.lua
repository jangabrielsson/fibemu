--%%name=Value Test
--%%remote=/panels/climate:*

a,b = api.get("/panels/climate/1")
print(a,b)
