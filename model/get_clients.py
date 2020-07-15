#Import other libraries
import pandas as pd
import numpy as np
import os
import pyodbc

def get_clients(conn, start_date, end_date):
    qry_path = os.path.join(os.getcwd(), 'sql', 'phs_strat_population.sql')
    qry_file = open(qry_path)
    sql = qry_file.read()
    qry_file.close()
    out = pd.read_sql_query(sql, conn, params = [start_date, end_date])
    return(out)
