from pathlib import Path

from shushu_internship_tool.interview_pack import extract_project_clues, write_interview_pack


def test_interview_pack_keeps_momentum_when_metrics_are_missing(tmp_path: Path) -> None:
    notes = tmp_path / "notes"
    notes.mkdir()
    (notes / "overview.md").write_text("Only architecture notes. No experiment result yet.\n", encoding="utf-8")

    project_clues = extract_project_clues(notes)
    paths = write_interview_pack(project_clues, tmp_path / "pack")

    resume = Path(paths["resume_star"]).read_text(encoding="utf-8")
    checklist = Path(paths["application_checklist"]).read_text(encoding="utf-8")

    assert "暂无明确指标线索" in resume
    assert "工程产出、方法理解、实验设计" in resume
    assert "指标或替代表达" in checklist
    assert "能投、能面、能讲" in checklist


def test_interview_pack_collects_metric_clues(tmp_path: Path) -> None:
    notes = tmp_path / "notes"
    notes.mkdir()
    (notes / "run.log").write_text(
        "baseline accuracy: 88.1%\nmodified accuracy: 91.2%\nlatency p50 12.4 ms\n",
        encoding="utf-8",
    )

    project_clues = extract_project_clues(notes)

    assert any("accuracy" in item["text"].lower() for item in project_clues["metric_hits"])
    assert any(item["source"] == "run.log" for item in project_clues["metric_hits"])
