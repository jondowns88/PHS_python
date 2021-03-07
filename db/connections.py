#Public packages
import os
import sys
from sqlalchemy import create_engine, event
import urllib

def php96_engine(uid, pwd):
    #Make connection string
    string = urllib.parse.quote_plus("DRIVER={SQL Server Native client 11.0};"
                                    r"SERVER=YOUR_SERVER;DATABASE=YOURDB;"
                                    r"UID="+uid+";PWD="+pwd+";MultiSubnetFailover=Yes;")

    #Connect to php96
    engine = create_engine("mssql+pyodbc:///?odbc_connect=%s" % string)
    return(engine)

def phclaims_engine():
    #Make connection string
    string = urllib.parse.quote_plus("DRIVER={SQL Server Native client 11.0};"
                                    r"SERVER=YOUR_SERVER;DATABASE=YOUR_DB;"
                                    r"Trusted_connection=yes;MultiSubnetFailover=Yes;")
    #Connect to php96
    engine = create_engine("mssql+pyodbc:///?odbc_connect=%s" % string)
    return(engine)

def hhsaw_engine():
    #Make connection string
    string = urllib.parse.quote_plus("DRIVER={ODBC Driver 17 for SQL Server};"
                                    r"SERVER=YOUR_SERVER;"
                                    r"DATABASE=YOUR_DB;"
                                    r"Trusted_connection=yes;MultiSubnetFailover=Yes;")
    #Connect to php96
    engine = create_engine("mssql+pyodbc:///?odbc_connect=%s" % string)
    return(engine)
