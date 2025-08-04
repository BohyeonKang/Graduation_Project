import random

# 알파벳 리스트 생성 및 섞기
alphabets = list("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
random.shuffle(alphabets)

print("알파벳에 대응하는 숫자를 입력하세요! (A=1, B=2, ..., Z=26)")

for ch in alphabets:
    correct_answer = ord(ch) - ord('A') + 1
    print(f"\n알파벳: {ch}")
    
    try:
        user_input = int(input("숫자 입력: "))
        if user_input == correct_answer:
            print("정답!")
        else:
            print(f"오답! 정답은 {correct_answer}입니다.")
    except ValueError:
        print(f"잘못된 입력입니다. 정답은 {correct_answer}입니다.")
