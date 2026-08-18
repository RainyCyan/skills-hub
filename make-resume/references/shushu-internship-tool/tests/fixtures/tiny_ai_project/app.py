from fastapi import FastAPI

app = FastAPI()


@app.get("/tickets/{ticket_id}")
def get_ticket(ticket_id: int) -> dict[str, int | str]:
    return {"id": ticket_id, "status": "open"}
