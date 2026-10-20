require "test_helper"

class MccResults::ResultPdfTest < ActiveSupport::TestCase
  Allotment = MccResults::ResultPdf::Allotment

  def result(name, round)
    MccResults::ResultPdf.new(file_fixture("#{name}.pdf"), year: 2023, round: round, workers: 1)
  end

  test "a single-round result gives one allotment per row and skips the legend page" do
    allotments = result("mcc_single_round", "STRAY").allotments

    assert_equal 42, allotments.size
    assert_equal [787, 1685, 1884], allotments.first(3).map(&:rank)
    assert_equal allotments.map(&:rank).sort, allotments.map(&:rank)
    assert_equal Allotment.new(
      year: 2023, round: "STRAY", rank: 787, quota: "All India",
      institute: "Sawai Man Singh Medical College, JAIPUR,Sawai Man Singh Medical College, JLN Marg, Jaipur-302004, Rajasthan, 302004",
      course: "M.D. (GENERAL MEDICINE)", allotted_category: "Open", candidate_category: "General", remarks: "Allotted"
    ), allotments.first
  end

  test "a wrapped institute joins every line of its cell, across blank lines" do
    allotment = result("mcc_single_round", "STRAY").allotments.find { _1.rank == 1685 }

    assert_equal "TOPIWALA NATIONAL MEDICAL COLLEGE,TOPIWALA NATIONAL MEDICAL COLLEGE B Y L Nair Ch Hospital, Dr. A.L. Nair Rd, Mumbai Central, Mumbai, Maharashtra, 400008", allotment.institute
    assert_equal "M.D. (RADIO- DIAGNOSIS)", allotment.course
    assert_equal %w[Open OBC], [allotment.allotted_category, allotment.candidate_category]
  end

  test "consecutive single-line rows stay separate" do
    allotments = result("mcc_single_round", "STRAY").allotments.index_by(&:rank)

    assert_equal ["GOA MEDICAL COLLEGE,Bambolim, Goa, Goa, 403202", "M.D. (PAEDIATRICS)", "General"], allotments[9711].to_h.values_at(:institute, :course, :candidate_category)
    assert_equal "HASSAN INSTITUTE OF MEDICAL SCIENCES, HASSAN,HASSAN INSTITUTE OF MEDICAL SCIENCES, HASSAN, Karnataka, 573201", allotments[9769].institute
    assert_equal "Govt. Medical College Akola,Govt. Medical College Akola, Maharashtra, 444001", allotments[9985].institute
    assert_equal ["M.S. (ORTHOPAEDICS)", "OBC"], allotments[10002].to_h.values_at(:course, :candidate_category)
  end

  test "a multi-round result keeps only this round's allotments" do
    pdf = result("mcc_multi_round", "R2")

    assert_equal (1..15).to_a, pdf.rows.map(&:rank)
    assert_equal({ quota: "-", institute: "-", course: "-", allotted_category: "-", candidate_category: "-", option: "-", remarks: "Did not opt for Upgradation." }, pdf.rows.first.cells)
    assert_equal [13, 14], pdf.allotments.map(&:rank)
    assert_equal Allotment.new(
      year: 2023, round: "R2", rank: 13, quota: "All India",
      institute: "PGIMER, DR. RML Hospital, Cannaught Place, New Delhi , ABVIMS, DR. RML Hospital, Baba Kharak Singh Marg, Cannaught Place, New Delhi",
      course: "M.D. (GENERAL MEDICINE)", allotted_category: "Open", candidate_category: "General", remarks: "Fresh Allotted in 2nd Round"
    ), pdf.allotments.first
  end

  test "six-digit ranks wrapped over two lines read as one rank" do
    pdf = result("mcc_wrapped_ranks", "R3")

    assert_equal [99993, 100005, 100014], pdf.allotments.map(&:rank)
    allotment = pdf.allotments.find { _1.rank == 100005 }
    assert_equal "All India", allotment.quota
    assert_equal "M.D. (PHARMA COLOGY)", allotment.course
    assert_equal %w[EWS EWS], [allotment.allotted_category, allotment.candidate_category]
    assert allotment.institute.start_with?("KING GEORG ES MEDICA L UNIVER SITY")
  end

  test "parsed ranks match pdftotext layout page by page" do
    %w[mcc_single_round mcc_multi_round mcc_wrapped_ranks].each do |name|
      check = MccResults::LayoutCheck.new(result(name, "R1")).run

      assert_empty check.mismatched_pages, name
    end
  end
end
