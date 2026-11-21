"""Reports API.

There is no authentication or authorization code here. Before a request
reaches this app, Istio has verified the token (audience reports-api) and
checked the reports-api client roles in it.
"""
from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI(title="reports-api")
reports = [{"id": 1, "title": "Q3 revenue"}]


class Report(BaseModel):
    title: str


@app.get("/reports")
def list_reports():
    return {"reports": reports}


@app.post("/reports", status_code=201)
def create_report(report: Report):
    created = {"id": len(reports) + 1, "title": report.title}
    reports.append(created)
    return created


@app.get("/healthz")
def healthz():
    return {"status": "ok"}
