; inherits: xml
; extends
;
(EmptyElemTag) @case_passed
(EmptyElemTag (Name) @case_passed_name (Attribute) @case_passed_att)
(EmptyElemTag 
  (Attribute 
    (Name) @case_passed_att_name
    (AttValue) @case_passed_att_value
  )
) 

(STag) @tag
(STag (Name)@tag_name (Attribute) @tag_att) 

(STag 
  (Attribute 
    (Name) @att_name
    (AttValue) @att_value
  )
)

(element) @element


(element 
  (content 
    (element 
      (content 
        (element 
          (content 
            (element 
              (STag) @not_passed
            ) 
          )
        )
      )
    )
  )
)

(element 
  (content 
    (element 
      (content 
        (element 
          (content 
            (element 
              (STag 
                (Attribute 
                  (Name) @not_passed_att_name
                  (AttValue) @not_passed_att_value
                )
              ) 
                (content) @not_passed_content 
            )
          )
        )
      )
    )
  )
)

(element 
  (content 
    (element 
      (content 
        (element 
          (content 
            (element 
              (STag 
                (Name) @not_passed_name 
                (Attribute) @not_passed_att
              ) 
                (content) @not_passed_content 
            )
          ) 
        ) 
      )
    )
  )
)

