#Public packages
import os
import sys
from sqlalchemy import create_engine, event
import urllib

#Function to automate the reading of queries.
def get_query(qry_string):
    qry_path = os.path.join(os.getcwd(), 'sql', qry_string)
    qry_file = open(qry_path)
    sql = qry_file.read()
    qry_file.close()
    return(sql)
