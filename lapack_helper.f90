!------------------------------------------------------------!
!         LAPACK helper module
!
! This module contains subroutines to perform matrix
! operations using the LAPACK library
!------------------------------------------------------------!
module lapackMod
contains
  function inv(A) result(Ainv)
    implicit none
    real,intent(in) :: A(:,:)
    real            :: Ainv(size(A,1),size(A,2))
    real            :: work(size(A,1))   ! work array for LAPACK
    integer         :: n,info,ipiv(size(A,1))   ! pivot indices
    ! Store A in Ainv to prevent it from being overwritten by LAPACK
    Ainv = A
    n = size(A,1)
    ! SGETRF computes an LU factorization of a general M-by-N matrix A
    ! using partial pivoting with row interchanges.
    call SGETRF(n,n,Ainv,n,ipiv,info)
    if (info.ne.0) stop 'Matrix is numerically singular!'
    ! SGETRI computes the inverse of a matrix using the LU factorization
    ! computed by DGETRF.
    call SGETRI(n,Ainv,n,ipiv,work,n,info)
    if (info.ne.0) stop 'Matrix inversion failed!'
  end function inv

  function dot_prod(A,B) result(C)
    implicit none
    real,intent(in) :: A(:,:)
    real,intent(in) :: B(:,:)
    integer :: m,n,k,ldA,ldB,ldC
    real :: C(size(A,1),size(B,2))

    m = size(A,1)
    n = size(B,2)
    k = size(A,2)
    ldA = m
    ldB = size(B,1)
    ldC = m

    call SGEMM('N','N',m,n,k,1.,A,ldA,B,ldB,1.,C,ldC)
  end function dot_prod

  subroutine svd(A,U,S,Sdiag,Vt)
    implicit none
    real,intent(in)  :: A(:,:)
    real,intent(out) :: U(:,:),S(:,:),Sdiag(:),Vt(:,:)

    integer           :: i,m,n,ierr
    real,allocatable  :: A_copy(:,:)

    m = size(A,1)
    n = size(A,2)

    allocate(A_copy(m,n),source=0.0,stat=ierr)
    if(ierr.ne.0) write (*,'(a,i8)') 'A_copy value of the error flag, INFO=',ierr

    A_copy = A

    write(*,*) 'SVD decomp started ...'
    if(m.gt.n) then
      call SVD_truncated_U(A_copy,U,Sdiag,Vt)
    else
      call SVD_truncated_V(A_copy,U,Sdiag,Vt)
    end if
    do i=1,min(m,n)
      S(i,i) = Sdiag(i)
    end do
  end subroutine svd

  !  SVD_truncated_U computes the SVD when N <= M.
  !    A(mxn) = U(mxm)  * S(mxn)  * V(nxn)'
  !           = Un(mxn) * Sn(nxn) * V(nxn)'
  subroutine SVD_truncated_U(a,un,sn,v)
    implicit none

    real,intent(inout)::  a(:,:)
    real,intent(out)  ::  un(:,:),sn(:),v(:,:)
    integer           ::  info,lda,ldu,ldv,lwork
    integer           ::  m,n
    character         ::  jobu,jobv
    real,allocatable  ::  work(:)

    m = size(A,1)
    n = size(A,2)
    lwork = 5*n+m
    allocate(work(lwork))

    jobu = 's'
    jobv = 'a'
    lda = m
    ldu = m
    ldv = n

    call SGESVD(jobu,jobv,m,n,a,lda,sn,un,ldu,v,ldv,work,lwork,info)

    if (info.eq.0) then
      write (*,'(a)')     ''
      write (*,'(a)')     ' SVD_truncated_U:'
      write (*,'(a)')     ' SGESVD computation was successful.'
    else
      write (*,'(a)')     ' '
      write (*,'(a)')     ' SVD_truncated_U - Warning!'
      write (*,'(a,i8)')  ' SGESVD returned INFO = ', info
    end if
  end subroutine SVD_truncated_U

  !  SVD_truncated_V computes the SVD when M <= N.
  !    A(mxn) = U(mxm) * S(mxn)  * V(nxn)'
  !           = U(mxm) * Sm(mxm) * Vm(mxn)'
  subroutine SVD_truncated_V(a,u,sm,vm)
    implicit none

    real,intent(inout)::  a(:,:)
    real,intent(out)  ::  u(:,:),sm(:),vm(:,:)
    integer           ::  info,lda,ldu,ldv,lwork
    integer           ::  m,n
    character         ::  jobu,jobv
    real,allocatable  ::  work(:)

    m = size(A,1)
    n = size(A,2)
    lwork = 5*n+m
    allocate(work(lwork))

    jobu = 'a'
    jobv = 's'
    lda = m
    ldu = m
    ldv = m

    call SGESVD(jobu,jobv,m,n,a,lda,sm,u,ldu,vm,ldv,work,lwork,info)

    if (info.eq.0) then
      write (*,'(a)')     ''
      write (*,'(a)')     ' SVD_truncated_V:'
      write (*,'(a)')     ' SGESVD computation was successful.'
    else
      write (*,'(a)')     ' '
      write (*,'(a)')     ' SVD_truncated_V - Warning!'
      write (*,'(a,i8)')  ' SGESVD returned INFO = ', info
    end if
  end subroutine SVD_truncated_V

  subroutine eigenvalues(A,WR,WI,VR)
    implicit none

    real,intent(in)  :: A(:,:)
    real,intent(out) :: WR(:)
    real,intent(out) :: WI(:)
    real,intent(out) :: VR(:,:)

    integer          :: ldVL,ldVR,ldA,lwork,ierr,info
    character        :: jobVL, jobVR
    real,allocatable :: work(:),VL(:,:)
    integer :: i,n

    n = size(A,1)

    jobVL = 'N' ! The left eigenvector u(j) of A satisfies: u(j)**H * A = lambda(j) * u(j)**H. 'N' to not compute.
    jobVR = 'V' ! The right eigenvector v(j) of A satisfies: A * v(j) = lambda(j) * v(j). 'V' to compute.
    ldA = n; ldVL = 1; ldVR = n

    lwork = max(1,5*n)
    allocate (work(lwork))

    write(*,*)
    write(*,*) 'Eigenmodes calculation started ...'
    call SGEEV(jobVL,jobVR,n,A,ldA,WR,WI,VL,ldVL,VR,ldVR,work,lwork,info)
    if(info.ne.0) then
      write(*,'(a)') 'SGEEV LAPACK - Failure!'
      write(*,'(a)') 'The eigenmodes could not be calculated.'
      write(*,'(a)') 'LAPACK routine SGEEV returned a nonzero'
      write(*,'(a,i8)') 'Value of the error flag, INFO=',info
      stop
    else
      write(*,*) 'Eigenmodes calculation finished successfully.'
    end if
  end subroutine eigenvalues

  subroutine print_eigenvalues(desc,WR,WI)
    implicit none
    character*(*),intent(in) ::  desc
    real,intent(in)          ::  WR(:),WI(:)
    integer ::  i,n

    n = size(WR)

    write(*,*)
    write(*,*) desc
    do i = 1,n
       if(WI(i).eq.0.0 ) then
          write(*,9998,advance='no') WR(i)
       else
          write(*,9999,advance='no') WR(i),WI(i)
       end if
    end do
    write(*,*)
    9998 format( 11(:,1x,f6.2) )
    9999 format( 11(:,1x,'(',f6.2,',',f6.2,')') )
  end subroutine print_eigenvalues
  ! *
  ! *     auxiliary routine: printing eigenvectors.
  ! *
  subroutine print_eigenvectors(desc,WI,V)
    implicit none
    character*(*),intent(in) ::  desc
    real,intent(in)          ::  WI(:),V(:,:)
    integer ::  i,j,n

    n = size(V,1)

    write(*,*)
    write(*,*) desc
    do i = 1,n
       j = 1
       do while(j.le.n)
          if(WI(j).eq.0.0) then
             write(*,9998,advance='no') V(i,j)
             j = j+1
          else
             write(*,9999,advance='no') V(i,j),  V(i,j+1)
             write(*,9999,advance='no') V(i,j), -V(i,j+1)
             j = j+2
          end if
       end do
       write(*,*)
    end do
    9998 format( 11(:,1x,f10.5) )
    9999 format( 11(:,1x,'(',f10.5,',',f10.5,')') )
  end subroutine print_eigenvectors
end module lapackMod
