import { HttpClient } from '@angular/common/http';
import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { User } from '../Model/user';
import { LoginCredentials } from '../Model/login-credentials';

@Injectable({
  providedIn: 'root'
})
export class GeneralService {

  base_url = "https://a07c32522a1d3484f9e27f8a3ccf35d2-99c5abae7ffd5d4a.elb.us-east-1.amazonaws.com/";
  constructor(private http: HttpClient) {   }

  public getUser(userId:number):Observable <any>{
    
    return this.http.get<User>(this.base_url+`user/${userId}`);
    
  }
  public loginUser(loginCredentials:LoginCredentials):Observable <any>{
    
    return this.http.post<User>(this.base_url+'login', loginCredentials);
    
  }
  public registerUser(User:User):Observable <any>{
    
    return this.http.post<User>(this.base_url+'signup', User);
    
  }
}
