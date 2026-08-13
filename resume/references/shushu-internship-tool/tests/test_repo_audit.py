from pathlib import Path

from shushu_internship_tool.repo_audit import audit_repo, write_audit_outputs


def test_repo_audit_generates_expected_signals(tmp_path: Path) -> None:
    fixture = Path(__file__).parent / "fixtures" / "tiny_ai_project"
    audit = audit_repo(fixture, name="tiny")

    assert audit["name"] == "tiny"
    assert "README.md" in audit["readme_files"]
    assert "requirements.txt" in audit["dependency_files"]
    assert "docker-compose.yml" in audit["dependency_files"]
    assert "routes/tickets.py" in audit["signals"]["api_backend"]
    assert "migrations/001_init.sql" in audit["signals"]["database_state"]
    assert "web/src/TicketPage.tsx" in audit["signals"]["frontend_mobile"]
    assert "train.py" in audit["signals"]["training"]
    assert "eval.py" in audit["signals"]["evaluation"]
    assert "tests/test_smoke.py" in audit["test_files"]

    paths = write_audit_outputs(audit, tmp_path)
    for path in paths.values():
        assert Path(path).exists()

    assert "Tiny" not in Path(paths["overview_html"]).read_text(encoding="utf-8")
    assert "项目摸底报告" in Path(paths["overview_html"]).read_text(encoding="utf-8")
